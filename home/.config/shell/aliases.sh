# shellcheck shell=sh
# エイリアス。sh 互換で書くこと。
# 新しい名前を付ける前に、既存コマンドとの衝突を確認する(CLAUDE.md「命名規則」参照)。

alias ll='ls -l'
alias la='ls -la'

# vi / vim / view は Neovim で置換する(nvim が入っている環境のみ。無い環境では通常の vi / vim / view のまま)
if command -v nvim >/dev/null 2>&1; then
  alias vi='nvim'
  alias vim='nvim'
  alias view='nvim -R' # view は読み取り専用モード(vi -R 相当)
fi
