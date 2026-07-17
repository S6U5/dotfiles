#!/usr/bin/env bash
#
# dotfiles backup
#
# install.sh が対象とするファイル(home/ 以下に対応する $HOME のファイル)のうち、
# 実際に $HOME に存在するものを、タイムスタンプ付きディレクトリに退避する。
# install.sh(特に --force)を実行する前に走らせることを想定。
#
# 使い方:
#   ./backup.sh                    # ~/.dotfiles-backup/backup-<日時>/ に退避
#   ./backup.sh /mnt/ssd/backup    # 退避先を指定(外付けSSD・クラウド同期フォルダなど)
#   ./backup.sh --dry-run          # 何が退避されるかの表示のみ
#
# - 退避のみ行い、$HOME 側は一切変更しない(副作用なし)。
# - リポジトリへのシンボリックリンク(導入済みのもの)は退避対象外。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_SRC="$DOTFILES_DIR/home"

DRY_RUN=0
DEST_BASE="$HOME/.dotfiles-backup"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      warn "不明なオプション: $arg"
      exit 1
      ;;
    *) DEST_BASE=$arg ;;
  esac
done

if [ ! -d "$HOME_SRC" ]; then
  warn "home/ ディレクトリがありません。退避対象なし。"
  exit 0
fi

DEST="$DEST_BASE/backup-$(date +%Y%m%d%H%M%S)"
count=0

while IFS= read -r -d '' src; do
  rel=${src#"$HOME_SRC"/}
  case "$rel" in
    .gitkeep | */.gitkeep) continue ;;
  esac
  target="$HOME/$rel"

  # 存在しないものは退避不要
  [ -e "$target" ] || continue

  # このリポジトリへのリンク(導入済み)は退避不要
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] 退避: $target -> $DEST/$rel"
  else
    mkdir -p "$DEST/$(dirname "$rel")"
    cp -a "$target" "$DEST/$rel"
    log "退避: $target -> $DEST/$rel"
  fi
  count=$((count + 1))
done < <(find "$HOME_SRC" -type f -print0 | sort -z)

log ""
if [ "$count" -eq 0 ]; then
  log "退避が必要なファイルはありませんでした。"
else
  log "完了: ${count} ファイルを退避しました。"
  if [ "$DRY_RUN" -eq 0 ]; then
    log "退避先: $DEST"
    log "外付け SSD やクラウドにもコピーしておくと安心です。"
  fi
fi
