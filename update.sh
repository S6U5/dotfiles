#!/usr/bin/env bash
#
# dotfiles update
#
# リポジトリを最新化(git pull)して、install.sh で新規ファイルのリンクを張る。
#
#   ./update.sh            # 更新
#   ./update.sh --prune    # 更新後、リポジトリ由来のリンク切れも掃除する
#   ./update.sh --dry-run  # pull はせず、リンク処理の内容表示のみ
#
# 安全設計:
#   - 未コミットのローカル変更(未追跡ファイル含む)があれば中断する(上書き事故防止)。
#   - pull は fast-forward のみ(--ff-only)。勝手にマージコミットを作らない。
#   - リンク処理は install.sh に委譲(冪等・既存ファイルは上書きしない)。
#
# nix/ に変更が入った pull の場合、home-manager switch の実行を促すメッセージを表示する
# (実行はしない。パッケージ導入は明示実行のみという方針のため。判断根拠は
# docs/decisions/package-management.md 参照)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

DRY_RUN=0
PRUNE_ARG=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --prune) PRUNE_ARG="--prune" ;;
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
  # shellcheck disable=SC2086
  "$DOTFILES_DIR/install.sh" --dry-run $PRUNE_ARG
else
  old_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
  git -C "$DOTFILES_DIR" pull --ff-only
  new_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
  # shellcheck disable=SC2086
  "$DOTFILES_DIR/install.sh" $PRUNE_ARG

  if [ "$old_head" != "$new_head" ] && ! git -C "$DOTFILES_DIR" diff --quiet "$old_head" "$new_head" -- nix/; then
    log ""
    log "nix/ に変更があります。反映するには以下を実行してください:"
    log "  home-manager switch --flake \"$DOTFILES_DIR/nix#<system>\" --impure"
    log "  (<system> は x86_64-linux / aarch64-linux / x86_64-darwin / aarch64-darwin から選択)"
  fi
fi
