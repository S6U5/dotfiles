# shellcheck shell=sh
# fzf を使う自作関数の置き場。fzf が無い環境では何も定義しない(エラーも出さない)。
# 履歴検索(Ctrl-R)・ファイル(Ctrl-T)・ディレクトリ移動(Alt-C)は
# fzf 公式のキーバインド統合で対応済み(.zshrc / .bashrc 側)。

if command -v fzf >/dev/null 2>&1; then
  # git ブランチを fzf で選んで切り替える(リモートブランチは追跡ブランチを自動作成)
  fbr() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "fbr: git リポジトリの中ではありません" >&2
      return 1
    fi
    # ローカルブランチ + リモート名を剥がしたリモートブランチを候補にする
    # (origin 以外のリモートにも対応。ローカルの feature/x を壊さないよう剥がすのはリモート側だけ)
    _fbr_sel=$(
      {
        git branch --format='%(refname:short)'
        git branch -r --format='%(refname:short)' | sed 's|^[^/]*/||'
      } | grep -vx 'HEAD' | sort -u | fzf --prompt='branch> '
    ) || {
      unset _fbr_sel
      return 0
    }
    if [ -n "$_fbr_sel" ]; then
      git switch "$_fbr_sel"
    fi
    unset _fbr_sel
  }
fi
