# git設定(.gitconfig)の管理方式

**方針は決定、templates/配布に変更済み**(旧: home/自動リンク + `[include]`分離。2026-08-03)。

## 検討した代替

- **home/自動リンク + `[include]`分離**(旧方式): `home/.gitconfig` をリポジトリ管理下に置き、
  `~/.gitconfig` にシンボリックリンク。機密(`user.name`/`user.email`等)は
  `[include] path = ~/.gitconfig.local` で分離し、`.gitconfig.local` は git 管理外にする。
- **templates/配布**(採用): 雛形をコミットし、`~/.gitconfig` へ手動コピー。以後 `~/.gitconfig`
  はリポジトリと物理的に無関係なファイルになる。

## 選んだ理由

`[include]` による分離機構自体は機能するが、これはユーザーが常に「機密は `.gitconfig.local` に
書く」という規律を守ることが前提になる。実際には `~/.gitconfig`(=リポジトリ管理下のシンボリック
リンク先)に直接 `[user]` 等を書いてしまう運用が起きうることが分かった。`~/.gitconfig` は
シンボリックリンクである以上、そこへの書き込みは即座にリポジトリ管理下ファイルへの書き込みになり、
コミット事故の入口になる。これは `docs/decisions/README.md` の AGENTS.md 側基準([APIキー等の
機密を書き込みうる単一ファイルはtemplates/配布にする理由)と同じ構造の問題であり、同じ理由で
templates/配布に切り替えた。

## トレードオフ

- 自動リンクではなくなるため、`home.nix` 等と違い `install.sh` 実行だけでは反映されない
  (`templates/git/README.md` の手順で手動コピーが必要)。
- 共通設定(`[diff]`/`[merge]`/`[alias]`等)を後から変更しても、既存マシンには自動反映されず、
  再度手動コピーしないと更新されない。
- `~/.gitconfig.local` による機密分離という考え方自体は変わらず維持している(テンプレート内で
  `[include]` している)。

## 履歴

- (2026-08-03: `home/.gitconfig` 自動リンク → `templates/git/.gitconfig.template` 配布に変更。
  本ADR作成。合わせて delta(git diffのシンタックスハイライトページャ)の設定をテンプレートに追加)
