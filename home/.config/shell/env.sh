# shellcheck shell=sh
# 環境変数。共通設定の中で最初に読み込まれる。
# 機密になりうる値(トークン、プライベートなパス等)はここに書かず local.sh へ(CLAUDE.md 参照)。

# 既定エディタ(nvim があれば nvim、無ければ vim。既に設定済みなら尊重)
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="${EDITOR:-nvim}"
else
  export EDITOR="${EDITOR:-vim}"
fi

# 設定ディレクトリを ~/.config に統一(macOS でも pnpm 等の XDG 対応ツールが ~/.config を読むように)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Homebrew(macOS)。zsh は ZDOTDIR 方式(docs/decisions/zshrc-pollution.md 参照)のため、
# brew インストール直後の案内が指示する `~/.zprofile` への追記は読み込まれず PATH が通らない。
# ディレクトリの有無だけで判定し、shellenv 相当の PATH 追加をここで行う。
for _brew_prefix in /opt/homebrew /usr/local; do
  if [ -x "$_brew_prefix/bin/brew" ]; then
    case ":$PATH:" in
      *":$_brew_prefix/bin:"*) ;;
      *) PATH="$_brew_prefix/bin:$_brew_prefix/sbin:$PATH" ;;
    esac
    break
  fi
done
unset _brew_prefix

# 自作コマンド置き場(home/.local/bin/)を PATH に通す(重複追加は避ける)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
