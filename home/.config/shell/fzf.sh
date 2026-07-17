# shellcheck shell=sh
# fzf を使うコマンド群。fzf が無い環境では何も定義しない(エラーも出さない)。

if command -v fzf >/dev/null 2>&1; then
  : # ここに fzf 系の関数を追加していく(履歴検索、ディレクトリ移動など。TODO.md 参照)
fi
