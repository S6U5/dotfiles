# dotfiles

[![Lint](https://github.com/S6U5/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/lint.yml)
[![Test](https://github.com/S6U5/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/test.yml)
[![Secrets scan](https://github.com/S6U5/dotfiles/actions/workflows/secrets-scan.yml/badge.svg)](https://github.com/S6U5/dotfiles/actions/workflows/secrets-scan.yml)


WSL / macOS / Linux で同じ環境を再現するための、個人用 dotfiles です。

> **注**: あくまで個人の設定(好みが濃いめ)です。そのまま使うより、構成や
> スクリプトの作りを参考にしたり、フォークして自分用に育てるのに向いています。

## 特徴

- **クロスプラットフォーム** — zsh / bash 両対応。macOS・WSL・Linux(Raspberry Pi 含む)で同じコマンド・設定が動きます
- **既存環境を侵略しない** — 既存ファイルは絶対に上書きせず(スキップ+警告)、置き換えは明示した時だけ・必ず退避してから。何度実行しても安全(冪等)
- **依存が無くても壊れない** — fzf や各アプリが無い環境でも、エラーを出さず動くか、親切に案内して終了します
- **機密ゼロ方針** — API キー・個人情報はリポジトリに置かず、git 管理外のローカルファイル(`*.local` / `local.sh`)へ分離。pre-commit フック+ CI の二段でコミット前後に機密混入を検査します
- **テスト済み** — インストール動作(リンク・冪等性・非侵略・掃除)を 24 項目の自動テストで検証し、CI で Ubuntu / macOS 両方に対して毎回実行しています

## クイックスタート

```sh
git clone https://github.com/S6U5/dotfiles.git
cd dotfiles
./backup.sh   # 既存の設定を ~/.dotfiles-backup/backup-<日時>/ に退避(推奨)
./install.sh  # home/ 以下を同じ構造で $HOME にシンボリックリンク
```

ツール一式(tmux / fzf / zoxide / shellcheck / shfmt)も入れるなら:

```sh
./packages/install.sh            # OS を判定して導入(macOS: Homebrew / Debian 系: apt)
./packages/install.sh --dry-run  # 何が入るかの表示のみ
```

パッケージ導入は設定のリンクとは独立しており、実行しなくても dotfiles 自体は壊れず動きます。

### 既存の設定ファイルとぶつかったとき(初回導入の正規ルート)

`~/.bashrc`(Ubuntu / WSL では OS が最初から設置)や `~/.gitconfig` など、**主要ファイルは初回導入時にほぼ必ず「スキップ+警告」になります**。これは異常ではなく、既存環境を黙って壊さないための設計です。警告された各ファイルはこう判断します:

1. 中身が不要、またはこのリポジトリに取り込み済み → `./install.sh --force`(`*.bak.<日時>` に退避してから置き換え)
2. マシン固有の値(名前・メール・キー等)が入っている → ローカル側ファイル(`~/.gitconfig.local` / `~/.config/shell/local.sh` / `~/.tmux.conf.local`)へ移してから `--force`
3. 判断に迷う → `backup.sh` の退避があるのでいつでも戻せます

### install.sh のオプション

| オプション | 動作 |
|---|---|
| (なし) | リンクを張る。既存ファイルはスキップ+警告 |
| `--dry-run` | 何が行われるかの表示のみ(変更しない) |
| `--force` | 既存ファイルを `*.bak.<日時>` に退避してからリンク |
| `--prune` | リポジトリ側で削除されたファイルの「リンク切れ」を掃除(このリポジトリ由来のリンクのみ対象) |

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
| `dotfiles-update [--prune]` | どこからでもこのリポジトリを更新(pull + 再リンク) |
| `notify <タイトル> [本文]` | デスクトップ通知(macOS / WSL / Linux 対応) |
| `cachesweep [--clean] [--docker]` | 開発ツールのキャッシュをサイズ表示・削除 |
| `wsl-compact [--sparse]` | WSL の仮想ディスクを圧縮して空き領域を Windows に返す |
| `fbr` | fzf で git ブランチを選んで切替(fzf のある環境のみ) |

このほか、fzf があれば Ctrl-R(履歴検索)/ Ctrl-T(ファイル)/ Alt-C(ディレクトリ移動)、zoxide があれば `z` での高速ジャンプが有効になります。

## リポジトリ構成

```
home/              $HOME に同じ構造でリンクされる設定ファイル群
├── .zshrc / .bashrc / .bash_profile   シェルのエントリポイント(zsh / bash 両対応)
├── .config/shell/                     シェル共通設定(sh 互換・機能別ファイル)
│   └── os/                            OS 固有の起動時設定(macos / wsl / linux)
├── .local/bin/                        自作コマンド(PATH に自動で通る)
├── .gitconfig / .tmux.conf / .npmrc   各ツールの共通設定
└── ...
packages/          パッケージリスト(Brewfile / apt.txt)と導入スクリプト
templates/         新プロジェクトにコピーして使う雛形($HOME にはリンクされない)
├── project/         開発プロジェクト用(AGENTS.md / CLAUDE.md / .editorconfig など)
├── project-generic/ 汎用(開発以外のプロジェクト向け AGENTS.md)
├── vscode/          VS Code 設定の雛形
└── claude/          Claude Code 設定の雛形
scripts/           lint(shellcheck / shfmt)・インストールテスト・push ロック
.githooks/         pre-commit フック(機密情報のコミットを自動ブロック)
```

マシン固有・プライベートな値は `~/.config/shell/local.sh` / `~/.gitconfig.local` / `~/.tmux.conf.local`(いずれも git 管理外)に置くと、共通設定の後に読み込まれて上書きできます。

## 更新

```sh
./update.sh            # 最新化(fast-forward のみ)+ 新規ファイルのリンク
./update.sh --prune    # あわせてリンク切れも掃除
```

どこからでも `dotfiles-update` コマンドで同じことができます。未コミットのローカル変更がある場合は安全のため中断します。

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
