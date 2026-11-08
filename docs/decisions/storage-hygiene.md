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
3. **MFT を読む**(ファイル数に依存しない、管理者権限): Windows は WizTree(`/export` で CSV を書ける。MFT を直接読むので 1TB でも数秒)。
4. **固定パスを歩く**(数秒): 場所が決まっている既知パスだけ `du -sx`。ローカル FS(ext4 / APFS)上に限る。
5. **全走査**(明示指定でのみ): WSL 内の vhdx は数十 GB で SSD 上のことが多く、`dua` / `gdu` の並列走査なら 1 分前後で終わる。これは「残差が出たときだけ 1 分かける」運用で成り立つ。`/mnt` 越しと Windows の巨大ドライブは 9P 経由でファイルを1つずつ読むため桁違いに遅く、ここだけは 1〜3 の手段に限る。

### OS 別の帳簿ソース

| カテゴリ | WSL 内 / Linux | Windows(WSL から) | macOS |
| --- | --- | --- | --- |
| 器 | `df` | `df /mnt/<x>`(drvfs / 9p のみ、timeout 付き) | `df`、Finder との差(= purgeable) |
| OS・システム | `journalctl --disk-usage`、`/var/cache/apt`、coredump | 「設定 → ストレージ」の「システムと予約済み」(帳簿が無いので開く) | `tmutil listlocalsnapshots /`、`/private/var/vm` |
| インストール済みアプリ | `dpkg-query -W -f='${Installed-Size}'`、`flatpak list --columns=size`、snap、**Nix store 全体**(`nix path-info --all -s`)と今の世代(`-S`)の差 | `reg.exe query …\Uninstall`(HKLM / WOW6432Node / HKCU)の `EstimatedSize`(KB。インストーラの申告なので目安。Store アプリは出ない) | `du /Applications/*`(バンドル単位で数秒)、Homebrew の Cellar |
| ユーザーデータ | `du` で各フォルダ(ローカル FS) | Everything → WizTree → 無ければ「ストレージ」設定を開く。`/mnt` 越しの `du` はしない | `du` で各フォルダ、大きいファイルは `mdfind` |
| クラウド同期 | (該当なし) | OneDrive フォルダはプレースホルダに注意(論理サイズで見える) | `~/Library/CloudStorage`、iCloud の退避可能分 |
| 仮想ディスク・コンテナ | `docker system df`(Engine) | Lxss の BasePath から各 `ext4.vhdx` を `stat`、`%LOCALAPPDATA%\Docker\wsl` | VM イメージの既知パス |
| アプリデータ・キャッシュ | 既知パス一覧(`~/.cache` 等) | Everything / WizTree に任せる | 既知パス一覧(`~/Library/{Caches,Application Support,Containers,Developer,Logs}`) |
| 開発成果物 | マーカー探索(明示指定) | 同左(ローカルに置く前提。`/mnt` 配下は遅い旨を注記) | 同左 |
| ごみ箱・バックアップ | `~/.local/share/Trash` | `$Recycle.Bin`、`Windows.old`(帳簿なし。ストレージ設定) | `~/.Trash`、`MobileSync/Backup` |

### 残差と時間軸

- 実行のたびに状態ファイル(`~/.local/state/dotfiles/diskreport.tsv`)に1行追記する: 時刻、器の使用量、カテゴリ別の合計、各既知パス。直近 30 回を保持し、「前回」「約1週間前」「約1か月前」との差を出せるようにする。
- 判定は残差そのものではなく**残差の増分**で行う。前回から残差が閾値(目安: 2GiB か全体の 5% の大きい方)を超えて増えたときだけ「一覧の外で増えている」と告げ、OS に応じた深掘り(WSL 内は全走査 TUI を 1 分、macOS は `mdfind`、Windows は Everything / WizTree か「ストレージ」設定)を薦める。
- Nix は「store 全体 − 今の世代」をそのまま「GC と世代削除で戻る上限」として出す(世代数より説得力がある)。

### 既知パス一覧の持ち方

- 共通の一覧はリポジトリのデータファイル(`home/.config/dotfiles/diskreport.paths`。タブ区切りで「カテゴリ、パス、何のデータか・消してよいか」)に出し、home-manager で配る。
- 個人の環境でしか意味の無い場所(特定アプリの保存先など)は git 管理外の `~/.config/dotfiles/diskreport.local` に同じ形式で足す。`local.sh` と同じ構図で、プライベートなパスをコミットせずに盲点を埋められる。
- 一覧は残差が出て原因が分かるたびに育てる。一覧を増やすときは「何のデータか・消してよいか」を必ず添える。

### 責務分担(変えない)

| 役割 | 担うもの |
| --- | --- |
| 上限(予防) | `nix-gc-setup`(`min-free` / `max-free`)、各ツールの設定(`cleanupPeriodDays` 等)。システム側(journald、Docker daemon)は README に書くだけ |
| 通知 | `switch.sh` の末尾で `diskreport --nix-brief`(表示だけ) |
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
- `/mnt` 越しの `du` をしないのは、9P 経由でファイルを1つずつ読むため WSL 内の数十倍遅く、速さでも精度でも Windows 側の帳簿(レジストリの `EstimatedSize`)、索引(Everything)、MFT 読み(WizTree)に勝てないから。Windows の中身は Windows の帳簿で見る。これらは OSS ではないが「呼び出すのは OK、組み込むのは NG」の範囲で、無ければ OS の「ストレージ」設定を開く。
- `min-free` / `max-free` は Nix 本体の機能で、ビルド中に空きが下限を切ったときだけ GC を走らせる。ビルドはユーザーが `switch` を打ったときにしか起きないので、「タイマーや起動時に勝手に走らせない」方針を崩さずに「気付かなくても溢れない」に寄せられる。GC で消えるのは誰からも指されていない store パスだけで、古い世代が指す分は残るため、世代の削除(戻せなくなる操作)は自動化せず、`switch` 直後に数字を出して人に委ねる。
- `min-free` の書き先を `nix-gc-setup` という明示コマンドにしたのは、複数ユーザー方式(nix-installer の既定、macOS は常に)では daemon が `/etc/nix/nix.conf` しか読まず、`home/` から配れるユーザー側の `nix.conf` では効かないため。home-manager 配布の対象外(システム設定)を扱う明示コマンドは `wsl-supplychain-setup` と同じ位置づけ。
- 削除を分析コマンドに持たせないのは、「cd 系は移動したときだけ 0」と同じ1コマンド1役割の方針と、読み取り専用なら `switch` の末尾から安心して呼べるため。

## トレードオフ・限界

- 残差は「知らない場所で増えた量」を言うだけで、場所は当てない。場所は深掘り(全走査 TUI、`mdfind`、Everything / WizTree)で探す。WSL 内の全走査は 1 分前後かかる。
- 帳簿の値は申告値で、実測とずれる。Windows のレジストリ `EstimatedSize` はインストーラが書いた KB 値で、書かないインストーラもあり Store アプリは出ない。dpkg の `Installed-Size` も同様に申告値。ずれは残差に吸収される。
- OneDrive のプレースホルダは論理サイズで見えるため、`du` で数えると実サイズより大きく出る。Windows 側の道具の「ディスク上のサイズ」で見るか、クラウド同期カテゴリの注記にとどめる。
- 新しいツールの上限を先回りする仕組みは作れない。残差で気付いてから個別に上限を入れる運用になる(世間にも先回りの手は無い)。
- 世代の削減は自動化しないので、`switch` 後の表示を見て人が `expire-generations` を打つ。
- Everything / WizTree / Storage Sense は Windows 専用、`mdfind` / `tmutil` は macOS 専用。各 OS で使える帳簿が違うため、OS 別の分岐は増える。無いものは静かに飛ばす。
- ユーザー側 `nix.conf` の `min-free` が daemon 構成で無視される点は Nix の挙動からの推定で、実機で `nix config show min-free` と実際のビルド時の GC で確かめる(確かめ次第ここに追記する)。

## 実装状況(2026-11)

- 実装済み: 器(`df`、WSL の Windows 側ドライブ・各 vhdx・他ドライブ)、Nix の世代数と今の世代、既知パスの `du` と前回差分、`--projects` のマーカー探索、`--windows`(Windows の「ストレージ」設定を開く)、`switch.sh` 末尾の通知、`nix-gc-setup`。
- 未実装(この設計で足すもの): カテゴリ別の会計と**残差**、履歴(直近 30 回)と残差の増分による判定、帳簿ソース(dpkg / flatpak / journald / `docker system df` / Nix store 全体 / Windows レジストリの `EstimatedSize`)、Everything(`es.exe`)と WizTree(`/export`)の連携、既知パス一覧の外部ファイル化と `diskreport.local`、macOS の `/Applications` と `mdfind`、クラウド同期とごみ箱・バックアップのカテゴリ。

## 履歴

- (2026-11: 導入。固定パス + 前回差分の `diskreport`、`nix-gc-setup`、`switch.sh` の通知)
- (2026-11: `diskreport --windows` は `/mnt` 越しの `du` をやめ、Windows の「ストレージ」設定を開くだけに変更。理由は本文「帳簿優先の原則」)
- (2026-11: 「固定パス + 前回差分」の3つの穴(一覧の外が見えない、`$HOME` しか見ていない、比較が一覧の中で閉じている)を受け、会計モデル(帰属 + 残差、帳簿優先)に設計を改めた。対象も開発キャッシュからマシンのストレージ全般へ広げた。本 ADR の本文を書き直し)
