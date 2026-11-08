# zsh の設定探索先を $HOME から丸ごと退避する(ZDOTDIR方式)。
# これにより $HOME 直下にはこのファイルしか置かれなくなり、ZDOTDIR を見ない
# インストーラが ~/.zshrc に自動追記しても孤立ファイルになるだけで実害が無い。
# 退避先の ~/.config/zsh/.zshrc 自体は dotfiles 管理外の実ファイル(home.activation が
# 生成する1行ローダー)なので、nvm 等 ZDOTDIR を尊重するインストーラの追記も
# リポジトリ管理下には届かない(判断根拠は docs/decisions/zshrc-pollution.md 参照)。
export ZDOTDIR="$HOME/.config/zsh"

# Ubuntu(WSL の既定ディストリを含む)の /etc/zsh/zshrc は、この変数が空だと全体設定として
# compinit を実行する(Ubuntu 固有のパッチ。同ファイルのコメントが $ZDOTDIR/.zshenv での
# 抑止を案内している)。設定本体(zshrc)側で compinit をキャッシュ付きで呼ぶため、ここで
# 抑止して二重実行を避ける。全体側の compinit は毎回フルの走査と安全性監査を行うので、
# zshrc 側の -C による高速化が効かなくなるうえ、監査に引っかかる環境(CI のランナー等)では
# 端末への問い合わせで止まる。
skip_global_compinit=1
