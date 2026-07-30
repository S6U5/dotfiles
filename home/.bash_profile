# shellcheck shell=bash
# bash のログインシェル用エントリポイント。設定は .bashrc に一本化し、ここでは読み込むだけ。
# (macOS の Terminal は bash をログインシェルとして起動するため、これが無いと .bashrc が
#  一切読まれない。Linux でもディストリ既定の ~/.profile に依存せず確実に読み込むため)
# shellcheck disable=SC1091  # 実行時の $HOME 上のファイルのため静的解析では追えない
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
