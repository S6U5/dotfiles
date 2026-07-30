#!/usr/bin/env bash
#
# Neovim を GitHub Releases の公式 tarball から ~/.local に導入するスクリプト(Linux/WSL 専用)。
#
# 背景(TODO.md 参照):
#   apt 版の Neovim は Ubuntu LTS だと数世代古く、kickstart.nvim 等が要求する
#   新しめのバージョンでは動かない可能性が高いため、apt は使わず公式バイナリを直接展開する。
#   macOS は packages/Brewfile(brew bundle)で導入する(このスクリプトは対象外)。
#
# 更新方法:
#   apt のようなバージョン管理された更新はない。このスクリプトを再実行すると
#   最新リリースを再ダウンロードして展開先を上書きするので、それが更新コマンドになる。
#
# 方針(CLAUDE.md 参照): 明示的に実行したときだけ動く。install.sh / update.sh からは呼ばれない。
#
# 使い方:
#   ./packages/neovim-install.sh
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "neovim-install: Linux/WSL 専用です。macOS は packages/Brewfile(brew bundle)で導入してください。" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) asset="nvim-linux-x86_64.tar.gz" ;;
  aarch64 | arm64) asset="nvim-linux-arm64.tar.gz" ;;
  *)
    echo "neovim-install: 未対応の CPU アーキテクチャです: $(uname -m)" >&2
    exit 1
    ;;
esac

dest="$HOME/.local/share/nvim-linux"
bin_link="$HOME/.local/bin/nvim"
url="https://github.com/neovim/neovim/releases/latest/download/$asset"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "neovim-install: $url をダウンロードしています..."
curl -fsSL "$url" -o "$tmp/nvim.tar.gz"

tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
extracted=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'nvim-linux-*')
if [ -z "$extracted" ]; then
  echo "neovim-install: 展開後のディレクトリが見つかりません。" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")" "$(dirname "$bin_link")"
rm -rf "$dest"
mv "$extracted" "$dest"
ln -sf "$dest/bin/nvim" "$bin_link"

echo "neovim-install: 完了。$("$bin_link" --version | head -n1)"
