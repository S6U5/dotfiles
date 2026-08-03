# dotfiles

[![Lint](https://github.com/S6U5/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/lint.yml)
[![Test](https://github.com/S6U5/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/test.yml)
[![Secrets scan](https://github.com/S6U5/dotfiles/actions/workflows/secrets-scan.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/secrets-scan.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20WSL%20%7C%20Linux-lightgrey)](#対応環境)

WSL / macOS / Linux で同じ環境を再現するための、個人用 dotfiles です。

> **注**: あくまで個人の設定(好みが濃いめ)です。そのまま使うより、構成や
> スクリプトの作りを参考にしたり、フォークして自分用に育てるのに向いています。

<img alt="dotfiles 実行時構造図: OS(macOS/WSL/Linux) → ターミナルエミュレータ → zsh → herdr → CLIアプリ(Neovim・fzf・zoxide)。herdrとCLIアプリを青枠の点線で囲み、Nix + Home Manager が導入・設定を管理する範囲を示す" src="docs/assets/stack.svg" width="620">

<img alt="dotfiles 設定ファイル配置図: home/ 以下のファイルが install.sh により $HOME へシンボリックリンクされる様子。zsh の .zshenv / .config/zsh/.zshrc は nix/home.nix(programs.zsh)が生成する" src="docs/assets/config-placement.svg" width="600">

## 目次

- [特徴](#特徴)
- [クイックスタート](#クイックスタート)
- [収録コマンド・関数](#収録コマンド関数)
- [リポジトリ構成](#リポジトリ構成)
- [更新](#更新)
- [テスト](#テスト)
- [push を無効化する(誤 push 防止)](#push-を無効化する誤-push-防止)
- [対応環境](#対応環境)
- [ライセンス](#ライセンス)

## 特徴

- **クロスプラットフォーム** — zsh / bash 両対応。macOS・WSL・Linux(Raspberry Pi 含む)で同じコマンド・設定が動きます
- **既存環境を侵略しない** — 既存ファイルは絶対に上書きせず(スキップ+警告)、置き換えは明示した時だけ・必ず退避してから。何度実行しても安全(冪等)
- **依存が無くても壊れない** — fzf や各アプリが無い環境でも、エラーを出さず動くか、親切に案内して終了します
- **機密ゼロ方針** — API キー・個人情報はリポジトリに置かず、git 管理外のローカルファイル(`*.local` / `local.sh`)へ分離。pre-commit フック+ CI の二段でコミット前後に機密混入を検査します
- **テスト済み** — インストール動作(リンク・冪等性・非侵略・掃除)を自動テストで検証し、CI で Ubuntu / macOS 両方に対して毎回実行しています

## クイックスタート

```sh
git clone https://github.com/S6U5/dotfiles.git
cd dotfiles
./backup.sh   # 既存の設定を ~/.dotfiles-backup/backup-<日時>/ に退避(推奨)
./install.sh  # home/ 以下を同じ構造で $HOME にシンボリックリンク
```

### パッケージ導入(Nix + home-manager)

ツール一式(tmux / fzf / shellcheck / shfmt / zoxide / neovim / ripgrep / fd / zsh-autosuggestions / zsh-syntax-highlighting 等)は **Nix + home-manager** でまとめて導入します。OS 非依存のマニフェストで管理でき、`nixpkgs-unstable` を追跡しているため WSL / Linux でも apt のように古いバージョンで止まりません(判断根拠は `docs/decisions/package-management.md` 参照)。

前提として Nix 本体のインストールが必要です。[NixOS/nix-installer](https://github.com/NixOS/nix-installer)(NixOS 公式が管理する、Determinate Nix Installer のフォーク。商用企業ではなく NixOS 自体が管理している点、flakes が扱える点、アンインストールが `nix-installer uninstall` で綺麗に戻せる点から、公式のクラシックインストーラより推奨)を使います:

```sh
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

インストール後、シェルを再起動(または新しいターミナルを開く)してから:

```sh
home-manager switch --flake ./nix#aarch64-darwin --impure     # 適用(Apple Silicon Mac の例)
```

`nix/flake.lock` はバージョンを固定するためリポジトリにコミット済みなので、通常は生成不要です。`nixpkgs` / `home-manager` のバージョンを更新したいときだけ `nix flake update ./nix` を実行してください。

`#` の後ろは環境に応じて `x86_64-linux` / `aarch64-linux` / `x86_64-darwin` / `aarch64-darwin` から選びます。dotfiles 自体(`home/` 以下)には影響しません。

`--impure` が必要なのは、実際のユーザー名をリポジトリにハードコードしないため `nix/home.nix` が `builtins.getEnv "USER"` で実行時に解決しているためです(flake の pure 評価では環境変数を読めません)。

zsh バイナリ(shell 実行ファイル)自体はここには含めていません。ログインシェルを Nix 管理下に置くとロックアウトのリスクがあるため、意図的に対象外にしています(判断根拠は `docs/decisions/login-shell.md` 参照)。一方で `.zshrc` / `.zshenv` の**内容**は `programs.zsh`(`nix/home.nix`)が生成します。oh-my-zsh・zsh-autosuggestions・zsh-syntax-highlighting もここで宣言的に管理しており、`home-manager switch` だけで新しい PC でも同じ状態が再現できます(bash 側は引き続き `home/` のシンボリックリンクで共通管理)。

古い世代やパッケージのガベージコレクションは home-manager / Nix 本体任せです(`home-manager expire-generations` や `nix-collect-garbage -d` 等)。日常のビルドでは直近の世代が GC root として保護されるため、ディスクを空けたくなったときに手動で実行してください。

#### zsh をログインシェルにする場合(任意)

- macOS: 標準で zsh が入っているため何もする必要はありません。
- WSL / Linux: zsh はディストリビューションの公式ドキュメントに従ってインストールし、`chsh` でログインシェルに設定してください(パッケージ名やコマンドはディストリごとに異なるため、配布元の公式ドキュメント・`man chsh` を参照)。

パッケージ導入(Nix)と設定のリンク(`install.sh`)は基本的に独立していて、Nix を実行しなくても dotfiles 自体は壊れず動きます。**ただし zsh だけは例外**です。zsh の `.zshrc`/`.zshenv` 自体を `programs.zsh` が生成するため、`home-manager switch` を一度も実行していない場合、zsh はエイリアス・関数・PATH追加(`~/.local/bin` 等)を含め設定ゼロの状態になります。zsh を使うなら `home-manager switch` は実質必須です(bash は引き続き `home/` 経由で Nix 無しでも機能します)。

### 既存の設定ファイルとぶつかったとき(初回導入の正規ルート)

`~/.bashrc`(Ubuntu / WSL では OS が最初から設置)や `~/.tmux.conf` など、**主要ファイルは初回導入時にほぼ必ず「スキップ+警告」になります**。これは異常ではなく、既存環境を黙って壊さないための設計です。警告された各ファイルはこう判断します:

1. 中身が不要、またはこのリポジトリに取り込み済み → `./install.sh --force`(`*.bak.<日時>` に退避してから置き換え)
2. マシン固有の値(名前・メール・キー等)が入っている → ローカル側ファイル(`~/.config/shell/local.sh` / `~/.tmux.conf.local`)へ移してから `--force`
3. 判断に迷う → `backup.sh` の退避があるのでいつでも戻せます

(`~/.gitconfig` は home/ 自動リンクの対象外です。`templates/git/README.md` の手順で手動セットアップしてください。)

### install.sh のオプション

| オプション | 動作 |
|---|---|
| (なし) | リンクを張る。既存ファイルはスキップ+警告 |
| `--dry-run` | 何が行われるかの表示のみ(変更しない) |
| `--force` | 既存ファイルを `*.bak.<日時>` に退避してからリンク |
| `--prune` | リポジトリ側で削除されたファイルの「リンク切れ」を掃除(このリポジトリ由来のリンクのみ対象) |
| `--uninstall` | このリポジトリが作成したリンク・ブートストラップファイル(`.bashrc`/`.bash_profile`)を削除。手を加えたブートストラップファイルは保護してスキップ。nix/home.nix が管理する zsh 設定・パッケージは対象外 |

リポジトリを別の場所へ移動した場合も、再実行すれば古いリンクが自動で張り替わります(他ツール由来のリンクには触れません)。

## 収録コマンド・関数

インストール後、新しいシェルから使えます。候補が複数あるものは fzf(あれば)か番号選択になり、引数で名前の絞り込みができます。

### 移動(cd 系)

| コマンド | 移動先 |
|---|---|
| `cdov [名前]` | Obsidian の vault(一覧は Obsidian 自身の設定から自動取得) |
| `cdic [名前]` | iCloud Drive |
| `cdgd [名前]` | Google Drive(マイドライブ / 共有ドライブ) |
| `cdod` / `cdode [名前]` | OneDrive(個人用 / 組織用) |
| `cdwin [サブフォルダ]` | Windows のユーザーフォルダ(WSL 用。Downloads 等は場所を移動していても正しく解決) |
| `cdgr` | git リポジトリのルート |
| `mkcd <dir>` | ディレクトリを作って移動 |
| `tmpd` | 使い捨ての一時ディレクトリ(掃除は OS 任せ) |

### アプリ起動

| コマンド | 動作 |
|---|---|
| `word` / `excel` / `powerpoint` / `outlook` / `onenote` `[ファイル]` | Office で開く(WSL では Windows 側の Office を起動。対応形式のみタブ補完・1ファイルまで) |
| `teams` | Microsoft Teams を起動 |
| `fusion360 [ファイル]` | Autodesk Fusion(旧 Fusion 360)で開く |
| `arduino [ファイル]` | Arduino IDE で開く(Linux に本物の arduino コマンドがあればそちらを優先) |
| `ov [名前]` | Obsidian を vault 指定で起動 |
| `explorer [パス]` | ファイルマネージャで開く(WSL: エクスプローラー / macOS: Finder / Linux: xdg-open) |

### ユーティリティ

| コマンド | 動作 |
|---|---|
| `dotfiles-update [--prune]` | どこからでもこのリポジトリを更新(pull + 再リンク。`nix/` に変更があれば `home-manager switch` の実行を促すメッセージを表示。実行はしない) |
| `notify <タイトル> [本文]` | デスクトップ通知(macOS / WSL / Linux 対応) |
| `cachesweep [--clean] [--docker]` | 開発ツールのキャッシュをサイズ表示・削除 |
| `wsl-compact [--sparse]` | WSL の仮想ディスクを圧縮して空き領域を Windows に返す |
| `fbr` | fzf で git ブランチを選んで切替(fzf のある環境のみ) |

このほか、fzf があれば Ctrl-R(履歴検索)/ Ctrl-T(ファイル)/ Alt-C(ディレクトリ移動)、zoxide があれば `z` での高速ジャンプが有効になります。

## リポジトリ構成

```
home/              $HOME に同じ構造でリンクされる設定ファイル群
             ※ zsh の .zshenv / .config/zsh/.zshrc は home/ の対象外(nix/home.nix の
               programs.zsh が生成。理由は「パッケージ導入(Nix + home-manager)」の節参照)
├── .config/bash/bashrc                bash 本体の設定(ブートストラップ方式)
├── .config/shell/                     シェル共通設定(sh 互換・機能別ファイル、zsh/bash 両方から source)
│   └── os/                            OS 固有の起動時設定(macos / wsl / linux)
├── .local/bin/                        自作コマンド(PATH に自動で通る)
├── .tmux.conf / .npmrc                各ツールの共通設定
└── ...

install.sh が生成するもの($HOME に直接置くが home/ には対応物が無い)
├── ~/.bashrc / ~/.bash_profile        dotfiles 管理外の実ファイル。~/.config/bash/bashrc を
│                                      読み込むだけの1行(判断根拠は docs/decisions/zshrc-pollution.md)
docs/              ドキュメント
├── cheatsheet/      このリポジトリで標準から変更・追加した設定のチートシート(アプリごとに分割: herdr.md / tmux.md / nvim.md)
├── decisions/       ADR(複数の選択肢から何を選んだか・なぜかの軽量な記録)
└── assets/          README 掲載図等
nix/               Nix + home-manager によるパッケージ管理(一本化)
templates/         新プロジェクトや機密を含みうる単一設定ファイルの雛形($HOME にはリンクされない)
├── project/         開発プロジェクト用(AGENTS.md / CLAUDE.md / .editorconfig など)
├── project-generic/ 汎用(開発以外のプロジェクト向け AGENTS.md)
├── vscode/          VS Code 設定の雛形
├── claude/          Claude Code 設定の雛形
└── git/             git 設定の雛形(.gitconfig.template。手動コピーして使う。判断根拠は docs/decisions/gitconfig-management.md)
scripts/           lint(shellcheck / shfmt)・インストールテスト・push ロック
.githooks/         pre-commit フック(機密情報のコミットを自動ブロック)
```

マシン固有・プライベートな値は `~/.config/shell/local.sh` / `~/.gitconfig.local` / `~/.tmux.conf.local`(いずれも git 管理外)に置くと、共通設定の後に読み込まれて上書きできます。`~/.config/shell/local.sh` と `~/.tmux.conf.local` は home/ 自動リンクされた共通設定への上書きですが、`~/.gitconfig` 自体は home/ 自動リンクではなく `templates/git/` からの手動コピー配布です(理由は `docs/decisions/gitconfig-management.md` 参照)。

## 更新

```sh
./update.sh            # 最新化(fast-forward のみ)+ 新規ファイルのリンク
./update.sh --prune    # あわせてリンク切れも掃除
```

どこからでも `dotfiles-update` コマンドで同じことができます。未コミットのローカル変更がある場合は安全のため中断します。`nix/` に変更が入った pull だった場合は `home-manager switch` の実行を促すメッセージが表示されます(自動実行はしません。パッケージ導入は明示実行のみという方針のため)。

## テスト

```sh
./scripts/test-install.sh
```

一時ディレクトリを HOME に見立てて、リンク配置・冪等性・既存ファイル非侵略・`--force` の退避・`--prune` の掃除範囲などを検証します(実際の `$HOME` は変更しません)。まっさらな環境で試すなら:

```sh
docker run --rm -v "$PWD":/dotfiles -w /dotfiles ubuntu:24.04 bash scripts/test-install.sh
```

## push を無効化する(誤 push 防止)

fetch/pull だけ使い、この clone からは push しないようにしたい環境向けです。ローカルの `.git/config` だけを変更するので、他の clone やリモート側には影響しません。

```sh
./scripts/lock-push.sh           # push を無効化
./scripts/lock-push.sh --unlock  # push を元に戻す
```

または `.devcontainer/` でコンテナとして開くと自動実行されます。

## 対応環境

WSL(Ubuntu)/ macOS / Linux(Debian 系・Raspberry Pi OS で確認想定)

## ライセンス

[MIT](LICENSE)
