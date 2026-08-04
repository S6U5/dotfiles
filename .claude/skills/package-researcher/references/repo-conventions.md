# このリポジトリのパッケージ導入まわりの規約(抜粋)

`CLAUDE.md` 本体から、`nix/home.nix` の判断に関係する部分だけを抜粋・要約したもの。
矛盾があれば `CLAUDE.md` 本体が正。

## 導入は「明示実行のみ」

- `home-manager switch --flake ./nix#<system> --impure` は **ユーザーが明示的に実行した
  ときだけ**動く。`update.sh`(pull のみ)からは絶対に呼ばれない。

## `nix/home.nix` の役割

- `home.packages` に導入したいパッケージ名を列挙する形式(`with pkgs; [ ... ]`)。
- パッケージ導入だけでなく、`home/` 配下の dotfiles 配布(`home.file` + `mkOutOfStoreSymlink`)
  も同じファイルで一本化している(判断根拠は `docs/decisions/dotfiles-distribution.md`)。
  package-researcher スキルが対象とするのは `home.packages` の追加・変更のみで、
  dotfiles 配布(`walkHome`)側のロジックは対象外。
- zsh 本体(ログインシェル)はここでは管理しない(判断根拠は `docs/decisions/login-shell.md`)。

## 商用ツールの扱い

- **組み込み(`nix/home.nix` への追加)は無償かつ OSS ライセンス(MIT/Apache/BSD/GPL 等)の
  ものに限る**。商用ライセンスのツールを前提に組み込まない。
- 商用・プロプライエタリなアプリを「呼び出す」コマンド(Obsidian, Office 等の起動コマンド)は
  別枠で問題ないが、これは `nix/home.nix` 導入の話とは別。

## 機密・プライバシー(最重要)

- API キー・トークン・プライベートなパス・個人情報は一切コミットしない。
- コメントにも、個人の事情や置かれている状況が分かる記述を書かない。

## 命名

- 新しいコマンド・スクリプトは既存コマンドと名前が衝突しないか `command -v <name>` で確認する。
- このリポジトリが定義する環境変数は `DOTFILES_` プレフィックス。

## 既存の判断の実例(参照用)

- **ripgrep / fd**: LazyVim(`home/.config/nvim/`)の全文検索・ファイル検索が要求する依存として
  `nix/home.nix` に追加。
- **herdr**(ターミナルマルチプレクサ、`docs/decisions/terminal-multiplexer.md` 参照):
  nixpkgs に `herdr` パッケージが存在し(`pkgs/by-name/he/herdr`、活発にメンテナンスされ
  `broken` 等のフラグなし)、herdr 公式もNixを明示的に非推奨としていないため Nix 管理を採用。
- 過去(2026-08-01 の Nix 一本化以前)は macOS(Homebrew)・Linux/WSL(apt)で個別に管理し、
  aptが古い・パッケージ名が違う等の問題があるツール(neovim・zoxide・fd)には専用の導入
  スクリプトを用意していたが、Nix 一本化によりこれらの問題自体が発生しなくなったため廃止した
  (判断根拠は `docs/decisions/package-management.md` の履歴参照)。
