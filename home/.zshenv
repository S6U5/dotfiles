# zsh の設定探索先を $HOME から丸ごと退避する(ZDOTDIR方式)。
# これにより $HOME 直下にはこのファイルしか置かれなくなり、nvm/pyenv/Homebrew 等の
# インストーラが ~/.zshrc に自動追記しても実害が無い(判断根拠は
# docs/decisions/zshrc-pollution.md 参照)。
export ZDOTDIR="$HOME/.config/zsh"
