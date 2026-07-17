# bash 用エントリポイント。共通設定(zsh と共有)を読み込み、bash 固有の設定はこのファイルに書く。

# 対話シェルでなければ何もしない
case $- in
  *i*) ;;
  *) return ;;
esac

[ -r "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"

# --- 以下、bash 固有の設定 ---

# 履歴
HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth
shopt -s histappend

# 補完(自作コマンドの補完定義は ~/.config/bash/completions/ に置く)
if [ -d "$HOME/.config/bash/completions" ]; then
  for _f in "$HOME/.config/bash/completions"/*.bash; do
    [ -r "$_f" ] && . "$_f"
  done
  unset _f
fi

# zoxide(賢い cd)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
