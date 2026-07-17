# shellcheck shell=sh
# エイリアス。sh 互換で書くこと。
# 新しい名前を付ける前に、既存コマンドとの衝突を確認する(CLAUDE.md「命名規則」参照)。

alias ll='ls -l'
alias la='ls -la'

# vim は Neovim で置換する(nvim が入っている環境のみ。無い環境では通常の vim のまま)
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
fi
