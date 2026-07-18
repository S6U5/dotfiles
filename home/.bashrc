# shellcheck shell=bash
# bash 用エントリポイント。共通設定(zsh と共有)を読み込み、bash 固有の設定はこのファイルに書く。
# ログインシェルからは .bash_profile 経由で読み込まれる。

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

# fzf のキーバインド(Ctrl-R: 履歴検索 / Ctrl-T: ファイル / Alt-C: ディレクトリ移動)
if command -v fzf >/dev/null 2>&1; then
  if _fzf_init=$(fzf --bash 2>/dev/null); then
    eval "$_fzf_init"
  elif [ -r /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    # apt 版など古い fzf(0.48 未満は --bash 非対応)向けフォールバック
    . /usr/share/doc/fzf/examples/key-bindings.bash
  fi
  unset _fzf_init
fi
