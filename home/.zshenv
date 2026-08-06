# zsh の設定探索先を $HOME から丸ごと退避する(ZDOTDIR方式)。
# これにより $HOME 直下にはこのファイルしか置かれなくなり、nvm/pyenv/Homebrew 等の
# インストーラが ~/.zshrc に自動追記しても実害が無い(判断根拠は
# docs/decisions/zshrc-pollution.md 参照)。
export ZDOTDIR="$HOME/.config/zsh"

# Debian/Ubuntu(WSL の既定ディストリビューション含む)ではグローバル設定
# /etc/zsh/zshrc が毎起動フルの compinit(compaudit + dump 検査)を実行し、
# これが起動時間の支配的要因になる(低速ディスクでは秒単位)。補完初期化は
# .zshrc 側で自前管理している(キャッシュ + 遅延実行)ため二重で不要であり、
# この変数で無効化する。他の OS・ディストリビューションでは未使用の変数に
# なるだけで無害(判断根拠は docs/decisions/zsh-startup-optimization.md 参照)
skip_global_compinit=1
