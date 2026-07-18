# shellcheck shell=sh
# fzf を使う自作関数の置き場。fzf が無い環境では何も定義しない(エラーも出さない)。
# 履歴検索(Ctrl-R)・ファイル(Ctrl-T)・ディレクトリ移動(Alt-C)は
# fzf 公式のキーバインド統合で対応済み(.zshrc / .bashrc 側)。

if command -v fzf >/dev/null 2>&1; then
  : # ここに fzf 系の自作関数を追加していく(git ブランチ切替など。TODO.md 参照)
fi
