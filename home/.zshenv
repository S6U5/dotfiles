# zsh の設定探索先を $HOME から丸ごと退避する(ZDOTDIR方式)。
# これにより $HOME 直下にはこのファイルしか置かれなくなり、ZDOTDIR を見ない
# インストーラが ~/.zshrc に自動追記しても孤立ファイルになるだけで実害が無い。
# 退避先の ~/.config/zsh/.zshrc 自体は dotfiles 管理外の実ファイル(home.activation が
# 生成する1行ローダー)なので、nvm 等 ZDOTDIR を尊重するインストーラの追記も
# リポジトリ管理下には届かない(判断根拠は docs/decisions/zshrc-pollution.md 参照)。
export ZDOTDIR="$HOME/.config/zsh"
