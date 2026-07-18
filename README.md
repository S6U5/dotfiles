# dotfiles

s6u5が自分用に作ったdotfilesです。

## 構成

- `home/` — `$HOME` に配置する設定ファイル群。この中のディレクトリ構造がそのまま `$HOME` にマッピングされます。
  - `.zshrc` / `.bashrc` — シェルのエントリポイント(zsh / bash 両対応)。どちらも共通設定を読み込みます。
  - `.config/shell/` — シェル共通設定(sh 互換)。環境変数・エイリアス・関数などを機能別ファイルで管理し、`os/` 以下で OS 固有設定(macOS / WSL / Linux)を読み分けます。
  - マシン固有・プライベートな設定は `~/.config/shell/local.sh`(git 管理外)に置くと最後に読み込まれます。
  - `.local/bin/` — 自作コマンド置き場(PATH に自動で通ります)。`dotfiles-update` でどこからでもリポジトリを更新できます。`word` / `excel` / `powerpoint` / `outlook` / `onenote` / `teams` で Office アプリを開けます(macOS はローカルアプリ、WSL は Windows 側の Office を起動。タブ補完は各アプリで開ける形式のみ・1ファイルまで。teams は起動のみ)。
- `install.sh` — インストールスクリプト
- `backup.sh` — インストール前に既存の設定ファイルを退避するスクリプト
- `update.sh` — リポジトリを最新化して新規ファイルのリンクを張るスクリプト(`git pull` + `install.sh`)
- `.githooks/` — 開発用 git フック。APIキー等の機密情報をコミット前に自動ブロックします(`install.sh` 実行時に有効化)。
- `templates/` — 新プロジェクトにコピーして使う雛形(`$HOME` にはリンクされません)。

## インストール

```sh
git clone https://github.com/S6U5/dotfiles.git
cd dotfiles
./backup.sh   # 既存の設定を退避(推奨)
./install.sh
```

`backup.sh` は install.sh が対象とする既存ファイルを `~/.dotfiles-backup/backup-<日時>/` に退避します(`$HOME` 側は変更しません)。退避先は `./backup.sh /path/to/dest` のように指定でき、外付け SSD やクラウド同期フォルダを指定しておくとより安心です。

`home/` 以下のファイルが同じ構造で `$HOME` にシンボリックリンクされます。

- **既存のファイルは上書きしません**(スキップして警告を表示)
- `./install.sh --dry-run` — 何が行われるかを表示するだけで、実際には変更しません
- `./install.sh --force` — 既存ファイルを `*.bak.<日時>` に退避してからリンクします
- `./install.sh --prune` — リポジトリ側で削除されたファイルの「リンク切れ」を掃除します(このリポジトリ由来のリンクのみ対象)
- 何度実行しても安全です(冪等)

## パッケージ導入(任意)

```sh
./packages/install.sh            # OS を判定してパッケージを導入
./packages/install.sh --dry-run  # 何が導入されるかの表示のみ
```

tmux や fzf など、dotfiles が使うツール一式を導入します(macOS: `packages/Brewfile`、Debian 系: `packages/apt.txt`)。設定のリンク(`install.sh`)とは独立しており、実行しなくても dotfiles 自体は壊れず動きます。

## テスト

```sh
./scripts/test-install.sh
```

一時ディレクトリを HOME に見立てて、リンク配置・冪等性・既存ファイル非侵略などを検証します(実際の `$HOME` は変更しません)。まっさらな環境で試す場合は Docker(`docker run --rm -v "$PWD":/dotfiles -w /dotfiles ubuntu:24.04 bash scripts/test-install.sh`)か、`.devcontainer/` でコンテナを開くと自動実行されます。

## 更新

```sh
./update.sh
```

リポジトリを最新化(fast-forward のみ)して、新しく追加されたファイルのリンクを張ります。未コミットのローカル変更がある場合は安全のため中断します。

## 対応環境

WSL / macOS / Linux
