# shellcheck shell=sh
# 環境変数。共通設定の中で最初に読み込まれる。
# 機密になりうる値(トークン、プライベートなパス等)はここに書かず local.sh へ(CLAUDE.md 参照)。

export EDITOR="${EDITOR:-vim}"

# 設定ディレクトリを ~/.config に統一(macOS でも pnpm 等の XDG 対応ツールが ~/.config を読むように)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# 自作コマンド置き場(home/.local/bin/)を PATH に通す(重複追加は避ける)
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
