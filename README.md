# dotfiles

s6u5が自分用に作ったdotfilesです。

## 構成

- `home/` — `$HOME` に配置する設定ファイル群。この中のディレクトリ構造がそのまま `$HOME` にマッピングされます。
- `install.sh` — インストールスクリプト
- `.githooks/` — 開発用 git フック。APIキー等の機密情報をコミット前に自動ブロックします(`install.sh` 実行時に有効化)。

## インストール

```sh
git clone https://github.com/S6U5/dotfiles.git
cd dotfiles
./install.sh
```

`home/` 以下のファイルが同じ構造で `$HOME` にシンボリックリンクされます。

- **既存のファイルは上書きしません**(スキップして警告を表示)
- `./install.sh --dry-run` — 何が行われるかを表示するだけで、実際には変更しません
- `./install.sh --force` — 既存ファイルを `*.bak.<日時>` に退避してからリンクします
- 何度実行しても安全です(冪等)

## 対応環境

WSL / macOS / Linux
