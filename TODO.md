# 検討事項・TODO

今後やること・決めることのメモ。決まったら CLAUDE.md に方針として昇格させる。

## シェル設定

- [x] どのシェルを主軸にするか — **zsh / bash 両対応**に決定(エントリポイント2つ+共通部は sh 互換。CLAUDE.md「シェル設定の構成」参照)
- [x] エイリアス・関数の置き場所の構成 — **機能別に分割**に決定(`home/.config/shell/` 以下。同上)
- [x] OS 分岐の実装パターン — `init.sh` 内の `case "$(uname -s)"` で `os/<os>.sh` を読み分ける方式に決定(同上)

## fzf 系コマンド

- [x] 履歴検索・ファイル検索・ディレクトリ移動 — fzf 公式キーバインド統合で対応済み(.zshrc / .bashrc。Ctrl-R / Ctrl-T / Alt-C。古い fzf には /usr/share の同梱スクリプトでフォールバック、無ければ静かにスキップ)
- [x] 自作関数の第1弾 — `fbr`(fzf で git ブランチ切替。リモートブランチは追跡ブランチを自動作成)を `fzf.sh` に実装済み。以降も欲しくなったら同ファイルに追加

## アプリ操作コマンド

- [x] Obsidian: vault へ移動する `cdov`・vault を指定して起動する `ov` — 実装済み(`home/.config/shell/obsidian.sh`。obsidian.json から vault 一覧を実行時取得、fzf があれば選択 UI、無ければ番号選択。ov は `obsidian://open?vault=` URI 起動)
- [x] クラウドストレージへ移動する `cdod`(OneDrive 個人用)/ `cdode`(OneDrive 組織用)/ `cdic`(iCloud Drive)/ `cdgd`(Google Drive)— 実装済み(`home/.config/shell/clouddrive.sh`。macOS / WSL のパスを実行時探索。OneDrive はフォルダ名で個人用/組織用を判別。Google Drive はフォルダ名の英日両対応)
- [ ] Obsidian: URI スキーム(`obsidian://`)でほかに何を操作するか(ノート作成、検索など)
- [ ] Obsidian 公式 CLI(`obsidian` コマンド)対応 — **方針は決定、実装は後日**(v1.12系/2026-02 一般提供。「起動中アプリのリモコン」で、未起動なら初回コマンドが起動)
  - **決定した方針**:
    - 公式 CLI を使う(コミュニティ製 `notesmd-cli` 等ではなく公式 `obsidian`)
    - macOS / ネイティブ Linux は**そのまま公式 CLI を使う**(macOS: `/usr/local/bin/obsidian` → アプリバンドル内 `obsidian-cli`。Linux: `~/.local/bin/obsidian`)
    - **WSL では Linux 版 CLI を入れない**。入れると WSLg 経由の Linux 版 Obsidian を操作してしまう。**WSL からは Windows ネイティブの Obsidian を interop で操作する**(Windows 側の `Obsidian.com` を叩く。`…\AppData\Local\Programs\Obsidian\`)。**WSLg は使わない**
    - 既存の `ov`(URI 起動)/ `cdov`(vault 移動)と同じ「WSL→Windows を叩く」流儀の延長。共通層(`obsidian.sh`)に「常に定義+実行時チェック」で置く
    - **トレードオフ/前提(世間の知見)**: Obsidian を WSL 内に入れて WSLg で GUI を出す派(vault を Linux FS に置ける)も一般的だが、それは不使用と決めた WSLg 依存。Windows ネイティブ版は **`\\wsl.localhost\...`(WSL の ext4 の奥)の vault をうまく開けない**。よって **vault は Windows 側(`/mnt/c/...` から見える場所)に置く前提**とする。既存 `obsidian.sh` が obsidian.json を Windows 側から読み `wslpath` で変換している作りとも整合
  - **検証段取り**: 現在の作業機は Mac。WSL 側の検証は Windows にこのリポジトリをクローンして後日実施する予定(macOS 分は手元で確認可能)
  - **未確定点(実機で要検証)**:
    - OS 差の吸収: macOS/Linux はネイティブ CLI をそのまま、WSL だけ Windows の `Obsidian.com` へルーティングするラッパー設計(`obsidian` 関数を共通層に置き、OS 分岐で委譲先を切り替える)
    - `.com` リダイレクタを WSL interop から実行できるか(フルパス指定・PATHEXT 依存の有無・引数の渡し方)
    - **パス形式の変換**: Windows はバックスラッシュ、Linux はスラッシュ。ファイルパス引数を取るコマンドで `wslpath` による相互変換が要る(既存 `_obsidian_pick` の `wslpath -u` と同じ発想)
    - 既存 `obsidian.sh`(`ov` の URI 方式)との関係 — 公式 CLI に寄せて置き換えるか、URI 起動と CLI 操作を併存させるか
    - Catalyst/Insider ゲートの扱い(未導入環境では `obsidian` 不在。存在チェックで親切メッセージ→正常終了)
    - **ユーザー名・env は不要の見込み**: Windows ユーザー名は既存 `_dotfiles_win_profile` と同様に interop で実行時解決できる(`cmd.exe /c 'echo %LOCALAPPDATA%'` → `…\Programs\Obsidian\Obsidian.com` を導く)。env が要るのは既定 vault 等の好み上書き用途くらいで、その場合のみ `DOTFILES_OBSIDIAN_*`
    - **Windows 側で CLI を動かすときの注意(要検証: WSL interop 経由でも当てはまるか)**:
      - 旧コンソールホスト(conhost)ではなく **Windows Terminal** を使う
      - **管理者権限のシェルだと CLI が無反応**になる報告あり(標準権限で実行)
      - `Obsidian.com` は PATHEXT で `.exe` より優先される「ターミナルリダイレクタ」。WSL からはフルパス指定で叩く想定
  - **ドキュメント方針**: 専用設計書は作らない(CLAUDE.md「ドキュメント」)。実装後にユーザー向け最小セットアップ手順だけ README に載せる。設計・注意点は本 TODO に集約
  - **README 掲載予定の下書き(人間向け前提環境・セットアップ)** — 実装時に README へ昇格:
    - 端末環境の目安: **Windows は Windows Terminal + WSL、macOS は標準ターミナル(Terminal.app)**
    - Obsidian v1.12.4+(CLI 一般提供版。該当期は Catalyst ライセンス)
    - 各 OS でネイティブに Obsidian をインストール(= CLI がバンドルされる)
      - macOS: そのまま `obsidian` が使える
      - WSL: **Windows 側に** Obsidian をインストール(WSL 内の Linux 版は入れない)
    - WSL の場合の環境:
      - **Windows の既定ターミナルを WSL にする**(端末を開いたら WSL に入る状態にする。Windows Terminal の既定プロファイルを WSL ディストロにする)
      - 端末アプリは **Windows Terminal** を使う(旧コンソールホストは避ける)
      - シェルは**標準権限**で起動(管理者権限だと CLI 無反応の報告)
      - WSL interop 有効(既定で有効。`Obsidian.com` を interop で叩ける前提)
    - CLI は「起動中アプリのリモコン」= Obsidian アプリが起動していること(未起動なら初回コマンドが起動)
- [x] 環境変数の命名規則 — **`DOTFILES_` プレフィックスに決定**(CLAUDE.md「命名規則」に昇格。現状は obsidian.json 自動検出のため実使用なし。将来 vault 指定等が必要になったら `DOTFILES_OBSIDIAN_VAULT` のように命名)
- [x] ネットワークドライブ(Z: 割り当て・NAS 等)連携 — **作らない(意図的な見送り)**。理由: ①サーバー名・共有名は業務情報・内部ネットワーク情報で最重要ルールに抵触しやすい ②sudo 必須・不通時のハング・ゴーストマウント等、挙動も危うい。必要になったら `local.sh`(git 管理外)に自分専用関数を書く
- [ ] WSL の Windows 連携(PowerShell)で作るコマンドの洗い出し(Office 系は `word` / `excel` / `powerpoint` / `outlook` / `onenote` として実装済み。共通実体は `office-open`。`explorer` も実装済み — WSL: エクスプローラー / macOS: Finder / Linux: xdg-open)

## .claude / .codex / .tmux 系

- [ ] どのファイルを管理対象にするか(機密・個人情報が混ざりやすいので要精査)
  - [x] `~/.claude/settings.json` — **テンプレート配布方式**で `templates/claude/settings.json.template` として管理(キーを書ける場所なので home/ の自動リンク対象にはしない。VS Code と同じ方式。使い方は templates/claude/README.md)。通知フックは osascript 直書きから、クロスプラットフォームの `notify` コマンド経由に変更済み
    - **API キーの扱い(決定)**: 雛形への直書きは禁止。必要になったらコピー先でのみ、`~/.config/shell/local.sh`(git 管理外)の環境変数か `apiKeyHelper` 方式にする。現在はサブスクリプションログインなので不要
  - [ ] 旧管理場所 `~/Configs/`(git 管理されていない前身)からの残りの移行: claude-code の `commands/*.md`(**プロンプトなので全文精査してから**)、`.mcp.json`(キーの有無を確認してから)、codex / vscode / tmux(`~/Configs/.tmux.conf` は取り込み済みの `~/.tmux.conf` と内容が違うので差分確認)
    - 注意: `~/.claude/managed-settings.json` へのリンクは**公式の読み込み場所ではない**(公式ドキュメント確認済み。macOS の正式配置は `/Library/Application Support/ClaudeCode/`)。おそらく効いていないので、移行時に中身を確認して user settings に統合するか廃止する
  - [ ] 移行完了後に `~/Configs` を廃止するか
- [x] `~/.claude/settings.json` など JSON 系は symlink でよいか — **テンプレート配布方式で決定**(symlink はしない。キーを書ける設定ファイルは home/ の自動リンクに入れない方針。このMacの旧 ~/Configs へのリンクは、切替時に手動でコピーに置き換える)
- [x] tmux — **丸ごとリンク方式**に決定(`home/.tmux.conf`)。既存 Mac の設定を取り込み済み。クリップボードは copy-command を OS 自動判別(要 tmux 3.2+)、マシン固有設定は `~/.tmux.conf.local`(git 管理外)に逃がす

## 個人用ツール設定(リンター・フォーマッター等)

- [ ] 普段使いのリンター・フォーマッターのグローバル設定を home/ に追加していく(候補: ruff、エディタ設定など。判断基準は CLAUDE.md 参照)
  - [x] `~/.shellcheckrc` — `home/.shellcheckrc` として追加済み(external-sources=true)
- [ ] 設定パスが OS で違うアプリ(VS Code 等)の扱い — install.sh に OS 別マッピングを足すか、chezmoi 導入の判断材料にする
  - [x] VS Code は当面**テンプレート方式**に決定 — `templates/vscode/settings.json.template` を各マシンの正しいパスへ手動コピーして使う(キー・マシン固有パスは雛形に書かずコピー先でのみ記入)。自動リンク化・Settings Sync 併用は将来検討

## install.sh / 運用

- [x] 更新用スクリプト `update.sh` 作成済み(pull --ff-only + install.sh。未コミット変更があれば中断)
  - リンク済みファイルとフックは pull だけで反映される。install.sh 再実行が要るのは home/ に新規ファイルが増えたときだけ
  - [x] どこからでも呼べる `dotfiles-update` — `home/.local/bin/dotfiles-update` として実装済み(エイリアスではなくコマンド。リンクをたどってリポジトリを自動特定)
- [ ] アンインストール(リンク解除)機能を作るか
  - [x] `install.sh --prune` 実装済み — home/ から削除したファイルの「リンク切れ」を自動掃除(リポジトリを指すリンクだけが対象。他ツールのリンクには触れない)
  - [ ] 全リンクを解除する完全アンインストールは必要になったら
- [x] 既存シェル設定への source 行追記 — **不要と決定**。`.zshrc` / `.bashrc` を丸ごとリンクで管理する構成にしたため、追記方式は使わない。既存設定があるマシンでは backup.sh で退避 → 必要な内容を home/ 側に取り込み → `--force` で切替、という運用
- [ ] 管理ツール(chezmoi / stow / yadm)の導入検討 — 有力候補は chezmoi(OS別テンプレート分岐・機密分離・diff 確認が要件に合う)
  - [ ] 導入するなら install.sh との関係をどうするか(置き換え? 併用?)
  - [ ] 導入タイミング(ファイル数・OS分岐が増えてきたら or 早めに試す)

## リポジトリ保護・PR 運用

- [ ] main のブランチ保護を設定する(直 push 禁止、PR 経由必須)
  - [ ] CI 必須(status check)にするか
  - [ ] 個人リポジトリなのでレビュー必須はどうするか(自分しかいないので不要?)
- [x] PR テンプレート(`.github/pull_request_template.md`)— 機密・個人情報チェックリストとして作成済み
- [ ] Issue テンプレートは OSS 公開時に用意する
- [ ] セットアップ手順は現状 README で十分。Brewfile 等で手順が増えたら SETUP.md に切り出す
- [ ] CODEOWNERS は個人リポジトリでは不要か
- [ ] 公開後の外部からの PR / Issue の受け入れ方針(CONTRIBUTING.md を書くか)

## 他のエンジニアがよくやっている取り組み(導入検討)

セットアップ自動化:

- [ ] ワンライナーインストール(`curl -fsSL .../install.sh | sh` で新マシンを一発セットアップ)
- [x] パッケージリストの管理 — `packages/` として実装済み(macOS: `Brewfile` + `brew bundle`、Debian 系: `apt.txt`。導入は `./packages/install.sh` の明示実行のみ、`--dry-run` あり)
  - パッケージ名の違いは OS 別リストで吸収する方針(各リストにそれぞれの名前で書く)
  - [ ] dnf(AlmaLinux 等)対応は必要になったら追加
  - 単一リポジトリで辛くなったら macOS 用 / Linux 用の分割も選択肢として残す
- [ ] `mise` / `asdf` で言語・ツールのバージョン管理(`.tool-versions`)

品質・テスト:

- [x] CI で shellcheck / shfmt — `scripts/lint.sh` + `.github/workflows/lint.yml` 導入済み。pre-commit フックでもツールがあれば実行
- [ ] CI でインストールテスト — まっさらな Ubuntu コンテナ + macOS ランナーで `install.sh` を実走させてクロスプラットフォーム動作を自動確認
  - [x] テスト本体 `scripts/test-install.sh` 作成済み(一時 HOME でリンク・冪等性・非侵略・シェル読み込み・コマンド動作を検証。macOS と Ubuntu 24.04 コンテナで合格確認済み)
  - [x] `.devcontainer/devcontainer.json` 作成済み(コンテナ起動時に test-install.sh を自動実行)
  - [x] CI 組み込み済み — `.github/workflows/test.yml`(ubuntu-latest + macos-latest で test-install.sh を実行)
- [ ] Docker の導入方針: **Docker Desktop は使わず Engine のみ**にしたい。Linux / WSL は docker-ce を公式 apt リポジトリから。macOS はネイティブ Engine 不可のため colima 等の軽量 VM 経由を検討(現状この Mac は Docker Desktop — 移行するかは要検討)

GitHub 連携:

- [ ] Codespaces / devcontainer 連携 — GitHub 設定で dotfiles リポジトリを指定すると起動時に自動適用される(`install.sh` が自動実行される)。**GitHub 側の設定が必要なので忘れないこと**

サプライチェーン対策:

- [x] npm — `home/.npmrc`(`ignore-scripts=true` + `save-exact=true`)
- [x] pnpm — `home/.config/pnpm/rc`(`minimum-release-age=10080` = 7日寝かせ。npm の未知キー警告を避けるため .npmrc と分離。macOS 対応のため env.sh で XDG_CONFIG_HOME を設定)
- [x] プロジェクト側の雛形 — `templates/project/renovate.json`(minimumReleaseAge 7日)と `templates/project/pnpm-workspace.yaml`(minimumReleaseAge 10080分)を作成済み
- [ ] bun / pip など他のパッケージマネージャの対策設定(bun は既定で postinstall 無効なので緊急度低。bunfig の寝かせ設定・pip のビルド時実行対策は使い始めるときに調査)

機密管理:

- [ ] age / SOPS で暗号化してコミットする方式の検討
- [ ] 1Password / Bitwarden CLI 連携(chezmoi 導入時の定番。テンプレートから実行時に注入)

見せ方・その他:

- [ ] README にスクリーンショット・機能一覧(OSS 公開時の「見せる dotfiles」化)
- [ ] `Makefile` / `justfile` で `make install` / `make test` などタスク整理
- [ ] Neovim 設定など肥大化するものは別リポジトリに分けるか検討
- [ ] Neovim 導入したい気持ちあり(難しくて保留中)。入るなら kickstart.nvim(最小テンプレートから育てる)か LazyVim(全部入り)か。まずはコミットメッセージ編集など部分導入から
  - **注意: ダウンロード方法によっては最新版を使えない問題がある**
    - apt の neovim は大幅に古い(Ubuntu LTS だと数世代前)。kickstart.nvim / LazyVim は新しめの Neovim を要求するため、**apt 版では動かない可能性が高い。`packages/apt.txt` に安易に追加しないこと**
    - 最新版を使う手段: macOS は brew(常に新しい)。Linux は公式 GitHub Releases のバイナリ / AppImage、または bob(Neovim 専用バージョンマネージャ)。Ubuntu なら unstable PPA も選択肢
    - Raspberry Pi(ARM)は対応バイナリがあるか要確認(公式の arm64 ビルドは比較的最近から)
    - 導入するときは「OS ごとに入手方法が違う」前提で packages/ の仕組みに組み込むか、専用の導入スクリプトを検討
    - **方針(決定): macOS は brew、WSL / Linux は公式 GitHub Releases の tarball を `~/.local` に展開**(`~/.local/bin/nvim`。sudo 不要・常に最新・更新は再実行するだけ)。バージョン切り替えが欲しくなったら bob を検討。WSL では apt / snap / AppImage / PPA は使わない
- [ ] GitHub のリポジトリトピックに `dotfiles` を付けて公開時に見つけやすくする(dotfiles.github.io にコミュニティの慣習まとめあり)

設定の中身でよくあるもの:

- [ ] プロンプトのカスタマイズ(starship が定番。TOML 1ファイルで全シェル・全OS共通にできる)
- [ ] `.gitconfig` の工夫
  - [x] `home/.gitconfig` 作成済み — `[include]` で `~/.gitconfig.local`(git 管理外)に名前・メール・マシン固有エディタを分離。共通側は pull.ff=only / push.autoSetupRemote / fetch.prune / quotepath=false / zdiff3 など
  - [ ] diff を見やすくする delta / difftastic の導入(OSS。packages/ に足すか検討)
- [ ] ターミナルエミュレータ設定(alacritty / wezterm / ghostty)も管理対象にする
- [x] `.editorconfig` をリポジトリに置く — 追加済み(雛形も `templates/project/.editorconfig` に)
- [x] Dependabot で GitHub Actions のバージョン更新を自動化 — `.github/dependabot.yml` 追加済み(月次)

## テンプレート集(新プロジェクト開始キット)

`home/` とは別に `templates/` ディレクトリを切って、新プロジェクトにコピーして使う雛形を貯める構想。
(`home/` に置くと install.sh で $HOME にリンクされてしまうため分離する)

- [ ] devcontainer テンプレート(`devcontainer.json` の雛形。言語別に複数用意するか)
- [x] `.editorconfig` 雛形 — `templates/project/.editorconfig` 作成済み
- [ ] 言語別 `.gitignore` 雛形
- [ ] GitHub Actions ワークフロー雛形
- [ ] Makefile / justfile 雛形
- [ ] テンプレートをコピーするコマンドを作るか(fzf で選択してコピーなど)
- [ ] プロンプトテンプレート(AI 系)
  - [x] プロジェクト用 `CLAUDE.md` / `AGENTS.md` の雛形 — 2種類作成済み(いずれも AGENTS.md 本体 + CLAUDE.md は `@AGENTS.md` 参照のみ。公式ベストプラクティス(200行未満・実行可能な具体例・理由付きルール・README と重複させない)と照合済み)
    - `templates/project/` — 開発プロジェクト用(コマンド・テスト・検証の例入り)
    - `templates/project-generic/` — 汎用(文書・調査・データ整理など開発以外でも使える。目的/操作/構成/ルール/完了条件/境界の6節)
  - [ ] Claude Code のカスタムスラッシュコマンド・スキル(`~/.claude/commands/` 等はユーザー設定なので `home/` 側、雛形は `templates/` 側と使い分け)
  - [ ] レビュー依頼・リファクタ依頼などよく使う定型プロンプト集
  - **注意(最重要)**: 個人的なこと・業務に関することはマジで一切含めない。プロンプトは特に混ざりやすいので、コミット前に必ず全文精査。疑わしければ入れない

devcontainer 連携(消費される側)の注意:

- [ ] VS Code `dotfiles.repository` / Codespaces 設定で dotfiles を指定する(GitHub/エディタ側の設定、忘れやすい)
- install.sh は「非対話・sudo 不要・高速」を維持すること(コンテナ内自動実行の前提)

## 診断からの持ち越し(意図的な見送り)

- [ ] pre-commit フックの改善(診断指摘・実害小のため見送り): ①lint がステージ内容ではなく作業ツリー全体を検査する ②gitleaks の `protect` サブコマンドが新バージョンで非推奨化予定。CI(gitleaks 全履歴)が二段目として機能しているため急がない
- [ ] update.sh の「未コミットの変更」検査は追跡ファイルのみ(未追跡ファイルは対象外。メッセージと検査範囲のずれ)
- [ ] install.sh のリンク済み判定は文字列比較のみ(リポジトリへ別パス経由でアクセスすると誤警告の可能性)

## 品質・公開準備

- [x] shellcheck を CI(GitHub Actions)で回す — 導入済み(上記)
- [x] 機密情報の事前ブロック — pre-commit フック(`.githooks/pre-commit`)導入済み(gitleaks 併用+内蔵パターン)
- [x] 機密情報の混入チェックを CI にも — `.github/workflows/secrets-scan.yml`(gitleaks。全履歴を検査)を追加済み
- [ ] **公開の可否そのものを再検討**(悩み中)。dotfiles 公開は「自分の攻撃対象領域(使用ツール目録・自動許可コマンド・環境の輪郭)を晒す」側面がある。機密ゼロは達成済みだが、OSINT 材料としての価値はゼロではない。判断材料: 自分の立場(標的価値)の変化、公開の得るもの(共有・ポートフォリオ)との比較。**公開しない=「公開できる規律のプライベートリポジトリ」も完成形として肯定する**
- [ ] OSS 公開前の最終レビュー(個人情報・プライベートパスの全ファイル確認、Claude テンプレの許可リストを載せるかの再精査、ツール目録の粒度)
- [ ] README の英語化をするか
