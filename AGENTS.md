# dotfiles

個人の dotfiles を管理するリポジトリ。

## 対象環境

- WSL
- macOS
- その他 Linux

クロスプラットフォームで使うため、設定は環境依存を避けるか、OS ごとに分岐できる構成にする。

### OS 固有コマンド

その OS でしか意味のないコマンド・関数も作ってよい。ただし対象 OS 以外では定義しない(または no-op にする)こと。

- WSL の例: エクスプローラーを開く(`explorer.exe`)、Office ソフトや PowerShell(`powershell.exe` / `pwsh.exe`)を開く、など Windows 連携系
- macOS の例: `open`、`pbcopy` / `pbpaste` 連携など
- Linux の例: `xdg-open` 連携など

WSL 判定は `/proc/version` に `microsoft` が含まれるか、`$WSL_DISTRO_NAME` の有無などで行う。

### アプリ操作コマンド

Obsidian などのアプリを操作するコマンドも追加予定。

- 導入制御は「**常に定義+実行時チェック**」方式とする:
  - コマンド自体は全環境で定義する(起動時の存在チェックによる条件定義はしない)。
  - 実行時にアプリ・依存が無ければ「〜が見つかりません」など親切なメッセージを出して正常終了する。
- アプリが無い環境でも壊れないようにする(存在チェック、外部ツール依存の方針と同様)。
- Obsidian は URI スキーム(`obsidian://`)経由で開くなど、OS ごとの開き方(`open` / `xdg-open` / `explorer.exe` 等)を吸収する。
- Vault のパスや名前などプライベートになりうる値はハードコードせず、環境変数や `*.local` ファイルから読む。

## リポジトリ構成

- `home/` — `$HOME` に配置する設定ファイル群。ディレクトリ構造がそのまま `$HOME` にマッピングされる(`home/.tmux.conf` → `~/.tmux.conf`)。新しい設定ファイルは基本ここに置く。配布は `nix/home.nix` の `walkHome` ヘルパーが `home/` を再帰的に走査して自動的に行う(新規ファイルを置くだけで対象になる)。**bash / zsh のエントリポイントは例外**で、設定本体(bash は `home/.config/bash/bashrc`、zsh は `home/.config/zsh/zshrc`)は対応する `$HOME` 上のパスに配布されるが、エントリポイント自体(`~/.bashrc` / `~/.bash_profile` / `~/.config/zsh/.zshrc`)は home/ 側に対応物が無い(`nix/home.nix` の `home.activation` が生成する管理外の実ファイル)。zsh の `home/.zshenv`(ZDOTDIR 設定のみ)は通常どおり home/ から配布される(理由は後述の「シェル設定の構成」、および `docs/decisions/zshrc-pollution.md` 参照)。
- `nix/` — Nix + home-manager による**パッケージ導入 + dotfiles 配布の一本化**(`flake.nix` + `home.nix`)。導入・反映は明示実行のみ(`home-manager switch --flake ./nix#<system> --impure`)。`home/` 配下は `home.file`(`config.lib.file.mkOutOfStoreSymlink`)で `home/` の実体ファイルへ直接シンボリックリンクする(Nix store へコピーしないため、`home/` を直接編集すればすぐ反映される)。`programs.zsh`/`programs.bash` のような設定生成モジュールは使わない(home-managerの生成ロジックに依存すると `switch` 未実行時に何も効かなくなるという過去の失敗があるため。判断根拠は `docs/decisions/zshrc-pollution.md` の履歴、`docs/decisions/dotfiles-distribution.md` 参照)。zsh バイナリ(ログインシェル本体)は引き続きここでは管理しない(判断根拠は `docs/decisions/login-shell.md` 参照。設定ファイルの生成元とログインシェル本体は独立した話)。**Nix が使えない環境ではこの dotfiles は機能しない**(フォールバックは意図的に作らない)。
  - **`nix/home.nix` にツールを追加・変更する前に、必ず公式リポジトリのメンテナンス状況(アーカイブされていないか、直近のコミット)と nixpkgs 側のパッケージが `broken` 等のフラグ付きでないかを確認する。**「〇〇を入れて」のように依頼側で決まっているように見える場合や、一見1行追記するだけの単純な依頼に見える場合でも省略しない。手順は `package-researcher` スキル(`.claude/skills/package-researcher/`)を参照。
- `templates/` — 機密を含みうる単一設定ファイルの雛形置き場。`$HOME` にはリンクされない(home/ と分離)。プロジェクト用のエージェント指示は `AGENTS.md` を本体とし、`CLAUDE.md` は `@AGENTS.md` 参照のみの薄いファイルにする(二重管理を避ける)。

## シェル設定の構成

- **zsh / bash 両対応。ただし2つの入口の構造は異なる**(判断の詳細は `docs/decisions/zshrc-pollution.md` 参照):
  - **zsh**: `home/.zshenv`(`~/.zshenv` に配布)が ZDOTDIR を `~/.config/zsh` に切り替えるだけの薄いファイル(ZDOTDIR方式)。エントリポイント `~/.config/zsh/.zshrc` は bash と同じ**ブートストラップ方式**: `nix/home.nix` の `home.activation` が生成する dotfiles 管理外の実ファイルで、中身は `~/.config/zsh/zshrc`(`home/.config/zsh/zshrc` から配布。実際の設定本体)を読み込むだけの1行。ZDOTDIR を見ないインストーラが `~/.zshrc` に追記しても孤立ファイルになるだけで無害、nvm のように ZDOTDIR を尊重するインストーラが `$ZDOTDIR/.zshrc` に追記しても管理外の実ファイルに落ちるだけで、リポジトリ管理下の設定は汚れない(mkOutOfStoreSymlink のリンク越しの追記は書き込みエラーにならず最終実体=リポジトリ内ファイルへ届いてしまうことが判明したため、エントリポイントを実ファイル化した。経緯は `docs/decisions/zshrc-pollution.md` の履歴参照)。Starship(プロンプト)・zsh-autosuggestions・zsh-syntax-highlighting は Nix の `home.packages` で導入し、`zshrc` 側で `command -v` / ファイル存在チェックの上で読み込む。oh-my-zsh は廃止済み(判断根拠は `docs/decisions/zshrc-pollution.md` の履歴参照。低速マウント上での起動遅延が理由)。
  - **bash**: bash には ZDOTDIR 相当の一括退避機構が無いため、**ブートストラップ方式**を採る。`~/.bashrc` / `~/.bash_profile` は `nix/home.nix` の `home.activation` が生成する dotfiles 管理外の実ファイル(シンボリックリンクではない。`home.file` にすると read-only になり、後述のインストーラ追記が失敗するため意図的に対象外にしている)で、中身は `~/.config/bash/bashrc`(`home/.config/bash/bashrc` から配布。実際の設定本体)を読み込むだけの1行。nvm/pyenv/Homebrew 等が `~/.bashrc` に自動追記しても、この2ファイルは元から管理対象外なので実害が無い。
  - どちらも共通設定 `home/.config/shell/init.sh` を source する(zsh 側は `home/.config/zsh/zshrc` の先頭で source する)。
- `home/.config/shell/` 以下(共通部)は **POSIX sh 互換**で書く。zsh / bash 固有の書き方が必要な設定は、共通部ではなく各シェルの設定本体(zsh は `home/.config/zsh/zshrc` / bash は `home/.config/bash/bashrc`)側に書く。
- 読み込み順(init.sh が制御):
  1. `env.sh` — 環境変数
  2. その他の `*.sh` — アルファベット順(`aliases.sh`、`fzf.sh`、`functions.sh`、…)。ファイルを追加すれば自動で読み込まれる
  3. `os/<os>.sh` — 実行中の OS のものだけ(`macos` / `wsl` / `linux` は排他。WSL では `wsl.sh` のみ読まれる)
  4. `local.sh` — git 管理外(gitignore 対象)。マシン固有・プライベートな設定は `~/.config/shell/local.sh` に直接置く
- 機能を追加するときは zsh 側の設定ファイルを太らせず、`home/.config/shell/` に機能別ファイルを追加する。
- **終了コードの決まり**: cd 系関数(cdov / cdod / cdwin 等)は**実際に移動したときだけ 0** を返す(候補なし・不一致・キャンセル・非対応 OS は非0。`cdod && コマンド` の合成事故を防ぐ)。アプリ起動系コマンドの「アプリ不在でも親切メッセージで正常終了(exit 0)」の方針は起動系に限る。
- WSL 判定・Windows ユーザーフォルダ解決は `functions.sh` の共通ヘルパー(`_dotfiles_is_wsl` / `_dotfiles_win_profile`)に一本化する(シェル関数層)。`home/.local/bin/` の独立スクリプトは同じ判定イディオムを使う。
- **OS 分岐の2系統の使い分け**: コマンド・関数は「常に定義+実行時チェック」で共通層(`home/.config/shell/` / `home/.local/bin/`)に置く。`os/<os>.sh` は**起動時設定(環境変数・エイリアス・PATH 調整など、その OS でだけ読み込ませたい宣言)専用**とする。現在 os/ 配下の各ファイル(`linux.sh` / `macos.sh` / `wsl.sh`)は説明コメントのみで実質的な起動時設定が無いため(プレースホルダとして維持)。
- **自作コマンド(実行可能スクリプト)は `home/.local/bin/` に置く**(`env.sh` で PATH に追加済み)。使い分け:
  - シェルの状態を変えるもの(`cd` する等)や一行で済むもの → 関数・エイリアス(`.config/shell/`)
  - 独立して動くもの・シェル以外からも呼びたいもの → `home/.local/bin/` のスクリプト(シェバン付き・実行権限付与)
  - スクリプト内でリポジトリのパスをハードコードしない。必要なら `dotfiles-update` のように自身のシンボリックリンクをたどって解決する。

## 運用方針

- **「設定の配置」と「パッケージ導入」は同じ経路(Nix + home-manager)に一本化する**(判断根拠は `docs/decisions/dotfiles-distribution.md` 参照)。導入・反映は明示実行のみ(`home-manager switch --flake ./nix#<system> --impure`。自動実行はしない)。
- リポジトリは単一で「共通レイヤー + OS別レイヤー」構造とする。OS別の管理が辛くなったら、リポジトリ分割も選択肢として残す(TODO.md 参照)。
- **既存ファイルとの衝突は home-manager 本体が検知する**。home.file が管理しようとするパスに既存ファイルがあると `home-manager switch` はエラーで停止する(黙って上書きしない)。`-b <拡張子>` オプションで既存ファイルを退避してから上書きできる(判断根拠・詳細は README「既存の設定ファイルとぶつかったとき」参照)。
- パッケージ管理は **Nix + home-manager に一本化する**(nix-darwin は対象外。判断の詳細は `docs/decisions/package-management.md`)。OS別のパッケージマネージャ(Homebrew / apt)を直接使う軽量な代替経路は廃止した。dotfiles 本体(`home/`)も Nix(home-manager の `home.file`)で配布する(zsh の設定内容も含む。判断根拠は `docs/decisions/dotfiles-distribution.md`、`docs/decisions/zshrc-pollution.md` の履歴参照)。**Nix が使えない環境ではこの dotfiles は機能しない**(意図的にフォールバックは作らない)。
- **OSS として公開済み**(「TODO.md の残項目を全て片付ける → Git の全履歴を1コミットに圧縮する → 公開に切り替える」の手順で実施済み。判断の詳細・履歴圧縮が必要だった理由は `docs/decisions/oss-publish-plan.md` 参照)。以下は絶対にコミットしない:
  - APIキー、トークン、パスワードなどの機密情報
  - プライベートなパス(実際のユーザー名を含む絶対パスなど)
  - メールアドレスや個人情報を含む設定(公開しても問題ないものは除く)
- 機密になりうる値は環境変数や `*.local` ファイル(gitignore 対象)に分離する。WSL では `wincred` コマンド(`home/.local/bin/`)で Windows 資格情報マネージャーに置き、`local.sh` には取得の呼び出しだけを書く方法も使える(判断根拠は `docs/decisions/secrets-storage.md`)。
- **商用ツールは「呼び出すのは OK、組み込むのは NG」**(本リポジトリは MIT で公開予定のため):
  - **組み込み NG**: `nix/` で導入するツール、dotfiles が動作の前提として依存するツールは、無償かつ OSS ライセンス(MIT / Apache / BSD / GPL 等)のものに限る。商用ライセンス・サブスクリプション認証が前提のツールを組み込まない(例: Docker は Desktop ではなく Engine のみ。判断の詳細は `docs/decisions/docker.md` 参照。Claude Code は OSS ではなく認証も必要なため `nix/` では導入せず、各自の通常のインストール手順に任せる)。
  - **呼び出し OK**: アプリ操作コマンド(`word` / `excel` / `ov` 等)が Office や Obsidian などの商用・プロプライエタリアプリを起動・操作するのは問題ない。ユーザー環境に既にあるものを呼び出すだけで、無い環境でも親切メッセージで正常終了する設計のため、依存にはならない。
  - 他リポジトリのコードを取り込む場合はライセンス互換に注意し、MIT と非互換のコードはコミットしない。
- **GitHub Actions のアクションはコミットハッシュで固定する**(`uses: owner/repo@<フル SHA> # vX.Y.Z` 形式。タグは後から書き換え可能でサプライチェーン攻撃の入口になるため)。バージョン更新は Dependabot がハッシュごと PR してくる。
- パッケージマネージャのサプライチェーン対策(`home/.npmrc` / `home/.config/pnpm/rc` / `home/.config/uv/uv.toml` の install スクリプト無効化・クールダウン等)は home-manager 配布の対象だが、Nix が動かない**ネイティブ Windows へは明示実行の `wsl-supplychain-setup`(`home/.local/bin/`)または README 記載の手動コピーで配る**(自動で走る配布機構は作らない。判断根拠は `docs/decisions/windows-supply-chain.md`)。対象ファイルを増やしたら、このコマンドのコピー対象と README のコピー先表も更新する。
- APIキー等は pre-commit フック(`.githooks/pre-commit`)で**コミット前に自動ブロック**される。gitleaks があれば併用、無くても内蔵パターンで検査。誤検知は該当行に `secrets-allow` コメントで回避(要目視確認)。フックは `nix/home.nix` の `home.activation`(`home-manager switch` 実行時)に `core.hooksPath` として自動有効化。
- 機密だけでなく**個人的なこと・特定の文脈が分かることは一切含めない(最重要ルール)**。設定内容に好みが出るのは当然だが、コメント・コミットメッセージ・設定値のどこにも、個人の事情・生活・所属や、置かれている状況が特定できる記述を書かない。
- **プロンプトテンプレートは特に要注意**。プロンプトには書いた人物の状況が特定できる文脈が極めて混ざりやすい。コミット前に必ず全文を精査し、少しでも疑わしければ入れない。

## lint・フォーマット

- シェルスクリプトは shellcheck(lint)と shfmt(フォーマット、`-i 2 -ci`)に準拠する。
- チェックは `./scripts/lint.sh`、自動修正は `./scripts/lint.sh --fix`。
- CI(`.github/workflows/lint.yml`)で必ず実行。ローカルの pre-commit フックでもツールがあれば実行される(無ければスキップ)。

## ツール設定を dotfiles に入れるかの判断基準

- **入れる**: `$HOME` 配下に置かれる「個人のグローバル設定」(例: `~/.shellcheckrc`、`~/.config/ruff/ruff.toml`、エディタのユーザー設定)。どのプロジェクトでも効かせたい個人の好みは dotfiles の領分。
- **入れない**: プロジェクトルートに置いてチームで共有する設定(`.eslintrc`、`.prettierrc`、`.editorconfig` 等)。これは各プロジェクトに属する。雛形として配りたい場合は `templates/` に置く。
- 注意: アプリによっては設定パスが OS で異なる(例: VS Code は Linux `~/.config/Code/User/`、macOS `~/Library/Application Support/Code/User/`)。現状の `home/` → `$HOME` 直マッピング(`walkHome` による機械的な配布)では吸収できないため、必要になったら `nix/home.nix` 側で `pkgs.stdenv.isDarwin` 等による OS 別分岐を追加して対応する。

### 管理方式の選択(home-manager 配布 か templates/ 配布か)

入れると決めた設定ファイルは、**機密を書き込みうるかどうか**で方式を分ける:

- **home-manager 配布**(`home/` 配下に置き、`nix/home.nix` の `home.file` で配布): 機密が混ざらないもの、またはツールが**分離機構を持ち、かつ実運用でその分離が確実に守られる**もの(ssh の `Include`、シェルの `local.sh` 読み込みのように、機密・マシン固有分を git 管理外ファイルへ逃がせるもの)。
- **templates/ 配布(テンプレート方式に統一)**: **API キー等の機密を書き込みうる単一ファイル**(例: Claude Code の `settings.json`、VS Code の `settings.json`、MCP 設定、git の `.gitconfig` など)。雛形をコミットし、各マシンへ手動コピー。キー・マシン固有値はコピー先でのみ記入し、雛形には絶対に書かない。`.gitconfig` は `[include]` という分離機構を持つが、シンボリックリンク先(=リポジトリ管理下ファイル)に直接書いてしまう運用事故が起きうるため、こちらに分類している(判断根拠: `docs/decisions/gitconfig-management.md`)。
  - 理由: home-manager 配布だと「実機であとからキーを足した」瞬間に git 管理下ファイルへの書き込みになり、コミット事故の入口になる。テンプレート方式なら実機の設定とリポジトリが物理的に切り離される。
  - 実機の設定を雛形へ還元するときが唯一の混入ポイントなので、その際は必ず全文精査する(特に `env` 欄)。

## ドキュメント

- 本格的な設計書は作らない。方針は `AGENTS.md`(`CLAUDE.md` は `@AGENTS.md` 参照のみの薄いファイル)、未決定の検討事項は `TODO.md` に書く。
- 検討事項が決まったら `TODO.md` から `AGENTS.md` の方針に昇格させる。
- **複数の選択肢の中から何かを選んだ理由(なぜ X 採用で Y は不採用か)は `docs/decisions/` に ADR(Architecture Decision Record)として残す**。設計書ではなく「決定1件につき1ファイル、数行程度」の軽量な記録(検討した代替・選んだ理由・トレードオフのみ)。書き方は `docs/decisions/README.md` 参照。AGENTS.md 側には結論とリンクだけ書き、詳細な比較・理由は ADR に逃がす。

## ブランチルール

- `main` は常に「そのまま使える」状態を保つ。
- 変更は作業ブランチで行い、main へマージする。個人リポジトリなので厳格な運用はしないが、壊れた状態を main に置かない。

## コミットメッセージ

- 先頭に種別を表す接頭辞を付ける(Conventional Commits の簡易版。`種別: 概要` の形式)。

  | 接頭辞 | 用途 |
  | --- | --- |
  | `feat:` | 新機能・新規追加 |
  | `fix:` | 不具合修正 |
  | `docs:` | ドキュメントのみの変更(README/AGENTS.md/ADR 等) |
  | `refactor:` | 挙動を変えないコード整理 |
  | `chore:` | 上記に当てはまらない雑務(依存更新、設定変更等) |
  | `ci:` | GitHub Actions 等 CI 設定の変更 |
  | `revert:` | 変更の取り消し |

- 迷ったら `chore:` にする。機械的な強制(コミットフック等)はせず、運用ルールとして守る。

## リポジトリ保護・PR 運用

- main は直push禁止・PR経由必須のブランチ保護を設定する(admin である自分への強制はしない。緊急時の直push退路を残すため)。CI(lint / home-manager-test / gitleaks)を required status check にする。個人リポジトリのためレビュー必須化はしない。
- 外部からの Pull Request は受け付けない(GitHub の `pull_request_creation_policy` を `collaborators_only` にして技術的に制限する)。Issue は受け付ける。
- 上記はいずれも GitHub の実設定として**設定済み**(公開への切り替え時に実施。main の branch protection は required status checks = lint / gitleaks / home-manager-test ×2、`pull_request_creation_policy` は `collaborators_only`)。判断の詳細は `docs/decisions/oss-publish-plan.md` 参照。
- コミットメッセージ・PR 本文に、Claude Code のセッション URL(`Claude-Session:` 行)や `Co-authored-by: Claude` 行、「Generated with Claude Code」等のフッターを**含めない**(作業文脈を残さない方針の一環。公開後に混入が発覚し、履歴書き換えで除去した経緯がある)。
- **ローカル側では pre-commit フック(`.githooks/pre-commit`)が main ブランチへの直接コミットを検知してブロックする**(実装済み)。サーバー側のブランチ保護は push した時点で初めて弾かれるため手戻りが大きく、特にエージェント(Claude Code等)がブランチルールを見落として main のまま作業を進めてしまう事故を、コミット時点で早期に検知する狙い。緊急時は `git commit --no-verify` で回避できる。

## 命名規則

- 自作コマンド・関数・エイリアスは、**既存コマンドやよく使われるコマンドと名前が被らない**ように注意する。
  - 例: `open`(macOS 標準)、`gs`(Ghostscript)、`gm`(GraphicsMagick)、`fd`、`z` など、標準コマンドや有名ツールと衝突しやすい名前は避ける。
  - 新しい名前を付ける前に `command -v <name>` / `type <name>` で衝突を確認する。
- 衝突しそうな場合はプレフィックスを付ける、より説明的な名前にするなどで回避する。
- **この dotfiles が定義する環境変数は `DOTFILES_` プレフィックス**を付ける。他ツールとの衝突を避け、出どころを明確にするため。内部用のシェル変数は `_dotfiles_` などアンダースコア始まりにする。

## 外部ツール依存の扱い

- fzf などの外部ツールを使うコマンド・関数を定義してよいが、**依存ツールが無い環境でも壊れない**ようにする。
  - `command -v fzf >/dev/null 2>&1` のように存在チェックしてから定義・実行する。
  - 可能ならフォールバック(例: fzf が無ければ通常の補完や `select` にする)、難しければ静かにスキップしてエラーを出さない。
- シェル起動時に依存ツール不在でエラーメッセージが出る状態にしない。
