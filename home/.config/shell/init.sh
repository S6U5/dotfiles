# shellcheck shell=sh
# shellcheck disable=SC1090,SC1091
#
# シェル共通設定のエントリポイント。zsh / bash 両方の設定本体から source される。
# この配下(home/.config/shell/)は POSIX sh 互換で書くこと(zsh / bash 両対応のため)。
#
# 読み込み順:
#   1. env.sh                  環境変数
#   2. その他の *.sh           アルファベット順(aliases.sh, fzf.sh, functions.sh, ...)
#                              dotfiles-dir.sh(DOTFILES_DIR の export)だけは home/ に実体が無く、
#                              nix/home.nix の home.file(text)がマシンごとに生成する
#                              (判断根拠は docs/decisions/dotfiles-dir-env.md)
#   3. os/<os>.sh              実行中の OS のものだけ(macos / wsl / linux は排他)
#   4. local.sh                git 管理外。マシン固有・プライベートな設定

_dotfiles_shell_dir="$HOME/.config/shell"

[ -r "$_dotfiles_shell_dir/env.sh" ] && . "$_dotfiles_shell_dir/env.sh"

for _dotfiles_file in "$_dotfiles_shell_dir"/*.sh; do
  case "$_dotfiles_file" in
    */init.sh | */env.sh | */local.sh) continue ;;
  esac
  [ -r "$_dotfiles_file" ] && . "$_dotfiles_file"
done

case "$(uname -s)" in
  Darwin) _dotfiles_os=macos ;;
  Linux)
    if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
      _dotfiles_os=wsl
    else
      _dotfiles_os=linux
    fi
    ;;
  *) _dotfiles_os="" ;;
esac
if [ -n "$_dotfiles_os" ] && [ -r "$_dotfiles_shell_dir/os/$_dotfiles_os.sh" ]; then
  . "$_dotfiles_shell_dir/os/$_dotfiles_os.sh"
fi

[ -r "$_dotfiles_shell_dir/local.sh" ] && . "$_dotfiles_shell_dir/local.sh"

unset _dotfiles_shell_dir _dotfiles_file _dotfiles_os
