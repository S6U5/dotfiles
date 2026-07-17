#!/usr/bin/env bash
#
# dotfiles update
#
# リポジトリを最新化(git pull)して、install.sh で新規ファイルのリンクを張る。
#
#   ./update.sh            # 更新
#   ./update.sh --dry-run  # pull はせず、リンク処理の内容表示のみ
#
# 安全設計:
#   - 未コミットのローカル変更があれば中断する(上書き事故防止)。
#   - pull は fast-forward のみ(--ff-only)。勝手にマージコミットを作らない。
#   - リンク処理は install.sh に委譲(冪等・既存ファイルは上書きしない)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

if ! git -C "$DOTFILES_DIR" diff --quiet || ! git -C "$DOTFILES_DIR" diff --cached --quiet; then
  warn "未コミットの変更があるため中断しました。コミットまたは退避してから再実行してください。"
  git -C "$DOTFILES_DIR" status --short >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "[dry-run] git pull はスキップします。"
  "$DOTFILES_DIR/install.sh" --dry-run
else
  git -C "$DOTFILES_DIR" pull --ff-only
  "$DOTFILES_DIR/install.sh"
fi
