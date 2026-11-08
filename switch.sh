#!/usr/bin/env bash
#
# dotfiles switch
#
# home-manager switch を実行し、パッケージ導入と home/ 配下の dotfiles 配布を反映する。
# 毎回手で揃える必要があった以下をまとめて肩代わりする(判断根拠は
# docs/decisions/home-manager-switch-invocation.md 参照):
#   - DOTFILES_DIR(nix/home.nix が home/ の実体パスを解決するための環境変数)を、
#     このスクリプト自身の場所から設定する
#   - <system>(x86_64-linux / aarch64-linux / aarch64-darwin)を uname から決める
#   - --impure を付ける(builtins.getEnv を使うため必須。README「--impure が必要な理由」参照)
#   - home-manager コマンドがまだ無い初回は、この flake が flake.lock で固定する
#     home-manager CLI を nix run で呼ぶ
#
#   ./switch.sh            # 反映
#   ./switch.sh -b bak     # 既存ファイルを .bak に退避して上書き
#                          # (引数はそのまま home-manager switch に渡す)
#
# 対象のクローンはこのスクリプトの場所で決まる(別のクローンを反映したいときは、その
# クローンの switch.sh を実行するか、そのクローンの中で dotfiles-switch を打つ)。
# どのクローンを対象に何を実行するかは、実行前に必ず表示する。反映はこのコマンドの明示実行のみで、自動では走らない(判断根拠は
# docs/decisions/package-management.md 参照)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export DOTFILES_DIR

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
  esac
done

if [ ! -f "$DOTFILES_DIR/nix/home.nix" ]; then
  warn "$DOTFILES_DIR に nix/home.nix がありません。dotfiles リポジトリの外で実行していませんか。"
  exit 1
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) system=aarch64-darwin ;;
  Linux-x86_64) system=x86_64-linux ;;
  Linux-aarch64 | Linux-aarch64_be) system=aarch64-linux ;;
  *)
    warn "未対応の環境です: $(uname -s)-$(uname -m)(対応システムは README「前提」参照)"
    exit 1
    ;;
esac

if ! command -v nix >/dev/null 2>&1; then
  warn "nix が見つかりません。先に Nix をインストールしてください(README「クイックスタート」参照)。"
  exit 1
fi

# 初回は home-manager コマンドがまだ無いため、この flake が公開する home-manager CLI
# (flake.lock に固定)へフォールバックする。レジストリ経由の `nix run home-manager` は
# 毎回 HEAD を未認証の GitHub API で解決するためレート制限で失敗することがあり、
# 固定版を呼ぶ方が再現性も高い(scripts/test-home-manager.sh と同じ)。
if command -v home-manager >/dev/null 2>&1; then
  cmd=(home-manager)
else
  cmd=(nix run "$DOTFILES_DIR/nix#home-manager" --)
fi
cmd+=(switch --flake "$DOTFILES_DIR/nix#$system" --impure "$@")

log "dotfiles switch: 対象 $DOTFILES_DIR($system)"
log "  \$ ${cmd[*]}"
exec "${cmd[@]}"
