#!/usr/bin/env bash
#
# dotfiles update
#
# リポジトリを最新化(git pull)する。dotfiles 本体の配布・パッケージ導入は
# home-manager に一本化しているため(判断根拠は docs/decisions/dotfiles-distribution.md
# 参照)、反映には別途 home-manager switch の実行が必要。
#
#   ./update.sh            # 更新
#   ./update.sh --dry-run  # pull はせず状態表示のみ
#
# 安全設計:
#   - 未コミットのローカル変更(未追跡ファイル含む)があれば中断する(上書き事故防止)。
#   - pull は fast-forward のみ(--ff-only)。勝手にマージコミットを作らない。
#
# home-manager switch は自動実行しない(パッケージ導入・dotfiles反映は明示実行のみ
# という方針のため。判断根拠は docs/decisions/package-management.md 参照)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      warn "不明なオプション: $arg"
      exit 1
      ;;
  esac
done

if ! git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  warn "$DOTFILES_DIR は git リポジトリではありません。"
  exit 1
fi

if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
  warn "未コミットの変更(未追跡ファイル含む)があるため中断しました。コミットまたは退避してから再実行してください。"
  git -C "$DOTFILES_DIR" status --short >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "[dry-run] git pull はスキップします。"
  exit 0
fi

old_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
git -C "$DOTFILES_DIR" pull --ff-only
new_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)

if [ "$old_head" != "$new_head" ]; then
  log ""
  log "更新を反映するには以下を実行してください:"
  log "  DOTFILES_DIR=\"$DOTFILES_DIR\" home-manager switch --flake \"$DOTFILES_DIR/nix#<system>\" --impure"
  log "  (<system> は x86_64-linux / aarch64-linux / aarch64-darwin から選択)"
  log ""
  log "同梱プラグインも更新する場合(Claude Code / Codex):"
  log "  agent-plugins-setup"
fi
