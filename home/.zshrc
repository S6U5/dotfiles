# zsh 用エントリポイント。共通設定(bash と共有)を読み込み、zsh 固有の設定はこのファイルに書く。

[ -r "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"

# --- 以下、zsh 固有の設定 ---

# 履歴
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_all_dups share_history

# 補完(自作コマンドの補完定義は ~/.config/zsh/completions/ に置く)
fpath=("$HOME/.config/zsh/completions" $fpath)
autoload -Uz compinit && compinit

# zoxide(賢い cd)。compinit の後に初期化する必要がある
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
