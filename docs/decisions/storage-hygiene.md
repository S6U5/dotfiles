# ストレージの扱い(会計モデル: 帰属 + 残差。上限の配布・明示コマンドでの通知・読み取り専用の分析)

**結論**: 容量の問題は「人が気付いてから掃除する」のではなく、(1) ツール側の上限を設定として配る、(2) 人が打った `switch` の直後に状態を知らせる、(3) 読み取り専用の分析コマンド `diskreport` で調べる、の3つで扱う(2026-11)。分析は**会計モデル**で設計する: ディスクの使用量を必ず「帰属できた分(カテゴリ別)」と「帰属できなかった分(残差)」に分け、前回からの**残差の増分**で「知らない場所で増えている」ことを量として検知する。数えるときは**帳簿(OS やパッケージ管理の集計)を先に引き、ファイルを1つずつ歩くのは最後の手段**にする。タイマーや自動削除は作らない。対象は開発キャッシュに限らず、OS・アプリ・ユーザーデータ・クラウド同期・仮想ディスクまで、そのマシンのストレージ全般。

> ステータス: 設計は確定。実装は段階的(末尾「実装状況」参照)。

## 背景

Nix は宣言的だが `/nix/store` は足すだけで勝手には引かない。`switch` のたびに世代が増え、nixpkgs の更新で土台ごと別物になった一式が積まれ、ソースビルドの材料も残る。README に GC の手動コマンドを書いて人の記憶に預けていたが、これは「気付けない圧迫」の典型で、この dotfiles が他の領域(シェル設定の汚染防止、機密の分離、サプライチェーン)で採ってきた「構造で起きなくする」思想が、ストレージにだけ適用されていなかった。

気付けない圧迫は3種類ある。(A) ファイル一覧に映らないもの(WSL の vhdx が中で消しても縮まない、macOS のローカルスナップショット、削除済みで掴まれたままのファイル、OneDrive のプレースホルダが論理サイズで見えること)、(B) 映るが誰も開かないアプリデータ、(C) ゆっくり増えるもの。世間の対策は「発生源で上限を切る」(journald の `SystemMaxUse`、Cargo 1.88 からの自動 GC、Nix の `min-free`、Claude Code の `cleanupPeriodDays`)、「前回との差を見る」(Prometheus の `predict_linear`、ncdu のエクスポート比較)、「ファイルを歩かず帳簿を読む」(WizTree の MFT 読み、Spotlight の索引、XFS の project quota)に寄っている。

最初の実装(固定パスの `du` + 前回差分)には3つの穴があった。(1) 一覧に無い場所は永遠に見えない、(2) `$HOME` しか見ておらず `/var/lib/docker` や journald、Nix store 全体が抜けている、(3) 比較が既知パスの中で閉じていて、一覧の外で増えても気付けない。会計モデルはこの3つを塞ぐための設計。

## 会計モデル

### 帰属カテゴリ(OS 共通の語彙)

| カテゴリ | 中身 | 性格 |
| --- | --- | --- |
| 器 | ファイルシステムの全体・使用・空き。WSL は Windows 側ドライブと各 vhdx | 全ての基準。ここから引く |
| OS・システム | ページ/休止ファイル、予約領域、スナップショット、復元ポイント、journald、coredump | 人は触らない。上限設定の対象 |
| インストール済みアプリ | OS のパッケージ管理やインストーラが申告したサイズ | 帳簿で取れる |
| ユーザーデータ | 書類・写真・動画・音楽・ダウンロード・デスクトップ | 人が開く場所。消す判断は人 |
| クラウド同期 | OneDrive / iCloud / Google Drive のローカルコピー | プレースホルダは論理サイズと実サイズが違う |
| 仮想ディスク・コンテナ | WSL の vhdx(他ディストリ含む)、Docker Desktop の vhdx、Docker Engine、VM イメージ | 中で消しても外は縮まない |
| アプリデータ・キャッシュ | `~/.cache`、`AppData\Local`、`~/Library/*` 等 | (B) の正体。既知パス一覧で測る |
| 開発成果物 | `node_modules` / `target` / `.venv` 等 | 再生成できる。マーカー探索(明示指定) |
| ごみ箱・バックアップ | Trash、iOS バックアップ、`Windows.old` | 消し忘れの定番 |
| **残差** | 器の使用量 − 上記の合計 | **知らない場所。これが設計の中心** |

### 帳簿優先の原則(どう数えるか)

数える手段を次の順で選ぶ。上にあるほど速く、ファイル数に依存しない。

1. **帳簿を引く**(走査なし、一瞬〜数秒): `df`、`stat`(vhdx 等の単一ファイル)、パッケージ管理の申告サイズ(dpkg の `Installed-Size`、flatpak、Windows レジストリの `EstimatedSize`)、Nix store の DB(`nix path-info --all -s` は DB を引くだけで、数千パスでも 1 秒未満)、`docker system df`、`journalctl --disk-usage`、`tmutil listlocalsnapshots`。
2. **索引を引く**(走査なし): macOS は Spotlight(`mdfind 'kMDItemFSSize > …'`)、Windows は Everything(`es.exe`。NTFS の USN ジャーナルで常時更新され、1.5 系はフォルダサイズも索引できる)。
3. **MFT を読む**(ファイル数に依存しない、管理者権限): 速いが、手軽に使える WizTree は個人利用のみ無料なので採らない(履歴参照)。
4. **固定パスを歩く**(数秒): 場所が決まっている既知パスだけ `du -sx`。ローカル FS(ext4 / APFS)上に限る。
5. **全走査**(明示指定でのみ): WSL 内の vhdx は数十 GB で SSD 上のことが多く、`dua` / `gdu` の並列走査なら 1 分前後で終わる。これは「残差が出たときだけ 1 分かける」運用で成り立つ。`/mnt` 越しと Windows の巨大ドライブは 9P 経由でファイルを1つずつ読むため桁違いに遅く、ここだけは 1〜3 の手段に限る。

### OS 別の帳簿ソース

| カテゴリ | WSL 内 / Linux | Windows(WSL から) | macOS |
| --- | --- | --- | --- |
| 器 | `df` | `df /mnt/<x>`(drvfs / 9p のみ、timeout 付き) | `df`、Finder との差(= purgeable) |
| OS・システム | `journalctl --disk-usage`、`/var/cache/apt`、coredump | 「設定 → ストレージ」の「システムと予約済み」(帳簿が無いので開く) | `tmutil listlocalsnapshots /`、`/private/var/vm` |
| インストール済みアプリ | `dpkg-query -W -f='${Installed-Size}'`、`flatpak list --columns=size`、snap、**Nix store 全体**(`nix path-info --all -s`)と今の世代(`-S`)の差 | `reg.exe query …\Uninstall`(HKLM / WOW6432Node / HKCU)の `EstimatedSize`(KB。インストーラの申告なので目安。Store アプリは出ない) | `du /Applications/*`(バンドル単位で数秒)、Homebrew の Cellar |
| ユーザーデータ | `du` で各フォルダ(ローカル FS) | `diskreport windows`(Windows 側の PowerShell で数える)。種類別は「ストレージ」設定。`/mnt` 越しの `du` はしない | `du` で各フォルダ、大きいファイルは `mdfind` |
| クラウド同期 | (該当なし) | OneDrive フォルダはプレースホルダに注意(論理サイズで見える) | `~/Library/CloudStorage`、iCloud の退避可能分 |
| 仮想ディスク・コンテナ | `docker system df`(Engine) | Lxss の BasePath から各 `ext4.vhdx` を `stat`、`%LOCALAPPDATA%\Docker\wsl` | VM イメージの既知パス |
| アプリデータ・キャッシュ | 既知パス一覧(`~/.cache` 等) | `diskreport windows` の索引。場所が決まっている開発キャッシュは `cachesweep` でも見られる | 既知パス一覧(`~/Library/{Caches,Application Support,Containers,Developer,Logs}`) |
| 開発成果物 | マーカー探索(明示指定) | 同左(ローカルに置く前提。`/mnt` 配下は遅い旨を注記) | 同左 |
| ごみ箱・バックアップ | `~/.local/share/Trash` | `$Recycle.Bin`、`Windows.old`(帳簿なし。ストレージ設定) | `~/.Trash`、`MobileSync/Backup` |

### 残差と時間軸

- 実行のたびに状態ファイル(`~/.local/state/dotfiles/diskreport.tsv`)に1行追記する: 時刻、器の使用量、カテゴリ別の合計、各既知パス。直近 30 回を保持し、「前回」「約1週間前」「約1か月前」との差を出せるようにする。
- 判定は残差そのものではなく**残差の増分**で行う。前回から残差が閾値(目安: 2GiB か全体の 5% の大きい方)を超えて増えたときだけ「一覧の外で増えている」と告げ、OS に応じた深掘り(WSL 内は全走査 TUI を 1 分、macOS は `mdfind`、Windows は `diskreport windows` か「ストレージ」設定)を薦める。
- Nix は「store 全体 − 今の世代」をそのまま「GC と世代削除で戻る上限」として出す(世代数より説得力がある)。

### 索引: 「数える」と「見せる」を分ける

- 細かさは数える手間に比例し、速さは見せる側の話なので、両立するには**数えるのを別のタイミングで1回だけ行い、結果(索引)を保存して、見せるときは索引を読む**。duc や ncdu のエクスポート、Spotlight と同じ発想。
- `diskreport scan` が索引を作る。`$HOME` 配下は `du -xkd 6`(深さ 6 までの全ディレクトリの累計サイズ)を1回。WSL では Windows 側ドライブを Windows 側の PowerShell に数えさせ、深さ 6 までのフォルダを取り込む。`C:\Windows` は数えず、ジャンクションとシンボリックリンクはたどらず、ローカルに実体の無いクラウドのファイルは 0 と数える。読めないフォルダの数は表示する。
- 普段のレポートは索引を読むだけで、「大きい順」「前回の索引から増えた順」「残差の候補(既知パスにも帳簿にも入っていない大きな場所)」「アプリ別」を一瞬で出す。索引には鮮度(何日前に数えたか)を必ず添える。「いま何があるか」ではなく「最後に数えたときに何があったか」を見せているため。
- 索引はディレクトリ単位(深さ 6 まで)に限り、ファイル単位は持たない。大きいファイル上位は `--deep` の仕事のまま。
- **「終わらない検査」にしない**: 重い処理は `--scan` の中だけで、既定 15 分(`DOTFILES_DISKREPORT_SCAN_TIMEOUT`)の `timeout` を付け、超えたら索引を保存せずに諦める。普段のレポートは木を歩かないので、ディスクの大きさに関係なく数秒で終わる。
- 常駐して索引を更新し続ける方式(fanotify のデーモン)なら鮮度の問題は消えるが、「常駐やタイマーを持たない」方針と衝突するので採らない。

### 使い方は1語に絞る(人に引数を覚えさせない)

- 覚えるのは `diskreport` だけ。普段はこれ一発で、索引があれば詳細・アプリ別・開発成果物・大きいファイルまで全部出す。索引が無い、または 30 日より古いときは、端末で対話中なら「今作りますか?」と聞く(端末でなければ案内だけ)。明示的に作り直す語は `diskreport scan`、Windows 側を数えて詳細を出す語は `diskreport windows`。`--nix-brief` は `switch.sh` が呼ぶ内部用で、人向けではない。
- 以前あった `--projects DIR` / `--deep` は廃止し、どちらも索引から自動で出す(開発成果物は索引の中の `node_modules` / `target` 等をマーカーで確認して集計、大きいファイルは scan のついでに拾う。macOS の大きいファイルは Spotlight から走査なし)。選択肢を増やすより「いつもの1語で全部出る」方が、覚えなくて済む。

### アプリ別の見方(どのパスを見ればよいかを固定する)

- OS ごとに「アプリがデータを置く決まった入れ物」があり、その直下のフォルダ名がアプリ名になる。この対応をコマンドに固定し、毎回調べない(AI に聞くたびに違うパスを教えられる、という問題への答え)。
  - Linux(XDG): `~/.config/<app>` 設定、`~/.cache/<app>` キャッシュ、`~/.local/share/<app>` データ、`~/.local/state/<app>` 状態。XDG に従わない古いアプリは `~/.<app>`。
  - macOS: `~/Library/Application Support/<app>` データ、`~/Library/Caches/<app>` キャッシュ、`~/Library/Containers/<bundle id>` サンドボックス、`~/Library/Group Containers`、`~/Library/Logs`。
  - Windows: `AppData\Local\<app>` このマシン限りのデータ・キャッシュ、`AppData\Roaming\<app>` 設定(移動する)、`AppData\LocalLow\<app>`、`AppData\Local\Packages\<store app>` ストアアプリ、`Program Files\<app>` 本体、`ProgramData\<app>` 全ユーザー共通。
- 索引からこれらの直下の行を拾い、フォルダ名(小文字化)で入れ物をまたいで合計し、入れ物ごとの内訳(設定 / キャッシュ / データ…)を添える。Windows はさらにレジストリの Uninstall キー(`DisplayName` と `EstimatedSize`)でインストーラの申告サイズの上位も出す。
- 限界: フォルダ名はアプリ名と一致しないことがある(macOS の Containers はバンドル ID、ベンダー名のフォルダの下にアプリが入る Windows の例)。「使っているか」は見ていない(最終利用日は別の帳簿: macOS の Spotlight `kMDItemLastUsedDate`、Windows の UserAssist。未実装)。

### 既知パス一覧の持ち方

- 共通の一覧はリポジトリのデータファイル(`home/.config/dotfiles/diskreport.paths`。タブ区切りで「カテゴリ、パス、何のデータか・消してよいか」)に出し、home-manager で配る。
- 個人の環境でしか意味の無い場所(特定アプリの保存先など)は git 管理外の `~/.config/dotfiles/diskreport.local` に同じ形式で足す。`local.sh` と同じ構図で、プライベートなパスをコミットせずに盲点を埋められる。
- 一覧は残差が出て原因が分かるたびに育てる。一覧を増やすときは「何のデータか・消してよいか」を必ず添える。

### 責務分担(変えない)

| 役割 | 担うもの |
| --- | --- |
| 上限(予防) | `nix-gc-setup`(`min-free` / `max-free`)、各ツールの設定(`cleanupPeriodDays` 等)。システム側(journald、Docker daemon)は README に書くだけ |
| 通知 | `switch.sh` の末尾で `diskreport --nix-brief`(表示だけ)。続けて、世代が 10 を超え 30 日より前のものがあれば、端末で対話中に限り「消して GC しますか?」と聞く(`y` で `expire-generations "-30 days"` と `nix-collect-garbage`) |
| 分析 | `diskreport`(読み取り専用。既定は 1〜4 の手段だけで数秒。全走査・成果物探索・Windows 側の道具は明示指定) |
| 削除 | `cachesweep` / `nix-collect-garbage` / `home-manager expire-generations` / `wsl-compact`、OS の道具(Storage Sense 等)。分析コマンドは案内するだけ |

## 検討した代替

| 観点 | 何もしない(README の手動コマンドのみ。従来) | 全走査 TUI だけ入れる | 固定パス + 前回差分(最初の実装) | 常駐索引(fanotify 系デーモン、duc の定期索引) | 会計モデル: 帰属 + 残差、帳簿優先(採用) |
| --- | --- | --- | --- | --- | --- |
| 人が覚えていなくても溢れない | × | × | △ | △ | △(上限設定と組み合わせて○) |
| 知らない場所の増加に気付ける | × | ○(毎回全部見れば) | × | ○ | ○(量として。場所は深掘りで) |
| 既定で数秒に収まる | ○ | ×(巨大な木で終わらない) | ○ | ○(索引後) | ○ |
| Windows 側(`/mnt` 越し)を扱える | × | ×(桁違いに遅い) | ×(遅い) | × | ○(帳簿・索引・MFT に限る) |
| タイマー・常駐を持たない方針と両立 | ○ | ○ | ○ | ×(常駐が要る) | ○ |
| 戻せなくなる操作を黙って行わない | ○ | ○ | ○ | ○ | ○ |

## 選んだ理由

- 「巨大な木を全部数えると終わらない、小さく絞ると意味が無い」のジレンマは、数える対象を減らすのではなく、**数えずに済む帳簿を先に引き、残りを残差として量で見る**ことで抜けられる。帰属できた分は帳簿の正確さで、帰属できなかった分は残差の増分で、それぞれ別の方法で監視する。
- 残差の「増分」を見る理由は、残差そのものには常に説明できない分(FS のメタデータ、帳簿の誤差、一覧の外の定常的なデータ)が含まれるから。増えたときだけ反応すれば、定常分は無視できる。
- `/mnt` 越しの `du` をしないのは、9P 経由でファイルを1つずつ読むため WSL 内の数十倍遅く、速さでも精度でも Windows 側の帳簿(レジストリの `EstimatedSize`)、Windows 側で動かす PowerShell に勝てないから。Windows の中身は Windows 側で数える。
- `min-free` / `max-free` は Nix 本体の機能で、ビルド中に空きが下限を切ったときだけ GC を走らせる。ビルドはユーザーが `switch` を打ったときにしか起きないので、「タイマーや起動時に勝手に走らせない」方針を崩さずに「気付かなくても溢れない」に寄せられる。GC で消えるのは誰からも指されていない store パスだけで、古い世代が指す分は残るため、世代の削除(戻せなくなる操作)は自動化せず、`switch` 直後に数字を出して人に委ねる。
- `min-free` の書き先を `nix-gc-setup` という明示コマンドにしたのは、複数ユーザー方式(nix-installer の既定、macOS は常に)では daemon が `/etc/nix/nix.conf` しか読まず、`home/` から配れるユーザー側の `nix.conf` では効かないため。home-manager 配布の対象外(システム設定)を扱う明示コマンドは `wsl-supplychain-setup` と同じ位置づけ。
- 削除を分析コマンドに持たせないのは、「cd 系は移動したときだけ 0」と同じ1コマンド1役割の方針と、読み取り専用なら `switch` の末尾から安心して呼べるため。

## トレードオフ・限界

- 残差は「知らない場所で増えた量」を言うだけで、場所は当てない。場所は深掘り(全走査 TUI、`mdfind`、`diskreport windows`)で探す。WSL 内の全走査は 1 分前後かかる。
- 帳簿の値は申告値で、実測とずれる。Windows のレジストリ `EstimatedSize` はインストーラが書いた KB 値で、書かないインストーラもあり Store アプリは出ない。dpkg の `Installed-Size` も同様に申告値。ずれは残差に吸収される。
- OneDrive のプレースホルダは論理サイズで見えるため、`du` で数えると実サイズより大きく出る。Windows 側の道具の「ディスク上のサイズ」で見るか、クラウド同期カテゴリの注記にとどめる。
- 新しいツールの上限を先回りする仕組みは作れない。残差で気付いてから個別に上限を入れる運用になる(世間にも先回りの手は無い)。
- 世代の削減は自動化しない。`switch` 後の表示と対話(y/N)で人が決める。案内だけでは溜まる(26 世代・store 15.5G のうち過去分 11.9G という例があった)ため、対話を足した。
- Everything / Storage Sense は Windows 専用、`mdfind` / `tmutil` は macOS 専用。各 OS で使える帳簿が違うため、OS 別の分岐は増える。無いものは静かに飛ばす。
- ユーザー側 `nix.conf` の `min-free` が daemon 構成で無視される点は Nix の挙動からの推定で、実機で `nix config show min-free` と実際のビルド時の GC で確かめる(確かめ次第ここに追記する)。

## 実装状況(2026-11)

- 実装済み(索引・アプリ別): `scan`(`$HOME` の `du -xkd 6`、WSL では PowerShell での集計、15 分の上限)、索引からの「大きい順」「増えた順」「残差の候補」「アプリ別」(入れ物直下の合計、Windows はレジストリの申告値の上位も)。入れ子の間引き(子1つが親の 8 割以上なら親を省く)。
- 実装済み: 器(`df`、満杯時の警告、macOS のスナップショット数、削除済みで使用中のファイル)、会計(カテゴリ別の合計と残差、入れ子の二重計上回避)、履歴(直近 30 回、前回・約1週間前・約1か月前との差)、残差の増分による警告、「いますぐ戻せる見込み」(キャッシュ + ごみ箱 + 開発成果物 + Nix の store 全体と今の世代の差 + Docker の未使用分)、帳簿ソース(journald、`/var/cache/apt` 等、dpkg の `Installed-Size`、flatpak / snap のディレクトリ、macOS の `/Applications`、Homebrew の Cellar、Nix store 全体、`docker system df`)、既知パス一覧の外部ファイル化(`home/.config/dotfiles/diskreport.paths` と git 管理外の `diskreport.local`)、`--projects`、`--deep`(macOS は `mdfind`、他は `find -size` と全走査 TUI の案内)、WSL の Windows 側(各 vhdx、Windows 側ドライブの `df`、レジストリ `EstimatedSize` による申告値の合計、他ドライブ)、`windows`(Windows 側を数えて詳細を出す)、`switch.sh` 末尾の通知、`nix-gc-setup`。作業ファイルは tmpfs を優先し、ディスクが満杯でもレポート自体は出る(履歴の保存だけ失敗して警告)。
- 未実装: Everything(`es.exe`)との連携(コマンドの書式を実機で確かめてから)、最終利用日(Spotlight / UserAssist)、クラウド同期のプレースホルダ(論理サイズ)の補正、XDG の `user-dirs.dirs` による書類フォルダ名の追従(一覧ファイルで足せる)。
- 実機未検証: `cachesweep` の Windows 側(PowerShell の動作は macOS の PowerShell 7 で確かめただけで、Windows PowerShell 5.1 と WSL からの起動は未実行。各ツールの置き場は既定の場所の知識に基づく)。WSL 分岐はスタブ(`reg.exe` / `wslpath` / `cmd.exe` / `powershell.exe` の偽物)で通しただけ。特に `diskreport windows` の集計(PowerShell)は macOS の PowerShell 7 と仮のフォルダで確かめただけで、Windows PowerShell 5.1 では未実行。実機で1回走らせて確かめる。macOS 分岐(`mdfind`、`tmutil`、`/Applications`、`stat -f`)は未実行。

## 履歴

- (2026-11: Windows 側の詳細を WizTree から Windows 側の PowerShell での集計に置き換え、`diskreport windows` で表示するようにした。WizTree は個人利用のみ無料で、商用利用できないツールは入れない方針にしたため。ファイルを1つずつ数えるので MFT 読みより遅いが、`diskreport scan` / `windows` の中だけの処理なので上限時間を付けて受け入れる。管理者権限が要らなくなり、確認ダイアログも出ない。読めないフォルダは数えられないので個数を表示する)
- (2026-11: `cachesweep` のサイズ表示に、WSL での Windows 側の開発キャッシュと、そのほかのパッケージツールの検出を足した。WizTree が無くても Windows 側のキャッシュの量が分かるようにするため。Windows 側の中身は Windows の道具で見る原則どおり、`/mnt` 越しの `du` ではなく Windows 側の PowerShell に決まった場所だけを数えさせ、上限時間を付けた。新しいコマンドは足さず、表示だけにして `--clean` は Windows 側に触れない。ツールは起動せず場所で検出する。corepack などは起動すると取得を始めることがあるため)
- (2026-11: 導入。固定パス + 前回差分の `diskreport`、`nix-gc-setup`、`switch.sh` の通知)
- (2026-11: `diskreport --windows` は `/mnt` 越しの `du` をやめ、Windows の「ストレージ」設定を開くだけに変更。理由は本文「帳簿優先の原則」)
- (2026-11: 集計の誤りを修正し、macOS 分岐を実機で確認。Docker Desktop では `docker system df` を会計に足さない。イメージは仮想ディスクのファイルの中にあり、そのファイルを別に数えているため。判定は OS ではなく `docker info` の OperatingSystem で行う。macOS でも Colima などは VM のファイルが一覧に無く、帳簿の値が唯一の帰属になるため。入れ子はカテゴリが違えば内側のカテゴリへ移す。大きいファイルは見かけのサイズではなく実割り当てで測る。疎ファイルの仮想ディスクとローカルに実体の無いクラウドのファイルが上位を占めるため)
- (2026-11: 「細かく、しかし速く」のために索引方式(`scan`)とアプリ別の見方を追加。重い処理に上限時間を付けた)
- (2026-11: 宣言のしかたは、世代が 10 を超えていて宣言が無いマシンでだけ、`switch` の最後の案内と y/N の質問のあとに短く出す。毎回出すと読み飛ばされるノイズになり、宣言済みのマシンには不要なため)
- (2026-11: 日数での指定 `DOTFILES_HM_KEEP_DAYS=D` も追加。両方書いたときは「どちらかの条件で残るものは残す」(D 日より古く、かつ直近 N 世代にも入らないものだけ消す)にした。nh clean の `--keep-since` / `--keep` と同じ意味で、片方の条件だけで戻し先が全部消える事故を避けられる。消す世代の番号は世代リンクの更新日時(`find -mtime`)で決めて `nix-env --delete-generations` に渡す)
- (2026-11: 世代数での指定を追加。`local.sh` に `DOTFILES_HM_KEEP_GENERATIONS=N` を書いたマシンでは、`switch` のたびに聞かずに直近 N 世代へ切り詰めて GC する。容量を切り詰めたい環境で 1 世代だけにしたい、という要件のため。毎回聞く形だと N=1 では毎回聞かれて意図と合わないので、マシンごとの明示的な宣言を同意とみなした。`home-manager expire-generations` は日時しか受け付けないため `nix-env -p <home-manager のプロファイル> --delete-generations +N` を使う(今の世代は消えない)。引数ではなく環境変数にしたのは、人に覚えさせず、マシン固有の設定は `local.sh` に置く既存の方針に合わせるため)
- (2026-11: 上記の質問が待たずに終わる不具合を修正。長いビルドの最中に押したキーが端末の入力バッファに残り、`read` がそれを答えとして読んでいた。質問の直前にバッファを読み捨て、答えは `/dev/tty` から直接読むようにした。答えが y 以外のときは、あとで打つコマンドを表示する)
- (2026-11: `switch.sh` の末尾で、世代が 10 を超え 30 日より前のものがあるときに限り、端末で対話中なら世代削除と GC を y/N で聞くようにした。表示と案内だけでは 26 世代まで溜まったため。`min-free` は空きが減ったときにしか動かず世代は消さないので、世代の上限はこの対話が担当する)
- (2026-11: 引数を `scan` / `windows` の2語に絞り、`--projects` / `--deep` は索引からの自動表示に置き換えた。索引が無い・古いときは対話で聞く)
- (2026-11: 「固定パス + 前回差分」の3つの穴(一覧の外が見えない、`$HOME` しか見ていない、比較が一覧の中で閉じている)を受け、会計モデル(帰属 + 残差、帳簿優先)に設計を改めた。対象も開発キャッシュからマシンのストレージ全般へ広げた。本 ADR の本文を書き直し)
