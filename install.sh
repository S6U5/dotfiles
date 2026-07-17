#!/usr/bin/env bash
#
# dotfiles installer
#
# home/ 以下のファイルを、同じディレクトリ構造で $HOME にシンボリックリンクする。
#
#   home/.zshrc          -> ~/.zshrc
#   home/.config/foo/bar -> ~/.config/foo/bar
#
# 方針:
#   - 既存ファイルは絶対に上書きしない。存在する場合はスキップして警告を出す。
#   - --force 指定時のみ、既存ファイルを *.bak.<timestamp> に退避してからリンクする。
#   - 何度実行しても安全(冪等)。リンク済みのものは何もしない。
#
# 使い方:
#   ./install.sh            # インストール(既存ファイルはスキップ)
#   ./install.sh --dry-run  # 何が行われるかの表示のみ
#   ./install.sh --force    # 既存ファイルを .bak に退避して上書き
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOME_SRC="$DOTFILES_DIR/home"

FORCE=0
DRY_RUN=0

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo wsl
      else
        echo linux
      fi
      ;;
    *) echo unknown ;;
  esac
}

link_file() {
  src=$1
  dest=$2

  # すでに正しいリンクなら何もしない
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "  ok:   $dest (リンク済み)"
    return 0
  fi

  # 既存ファイル・リンクがある場合
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
      run mv "$dest" "$backup"
      log "  bak:  $dest -> $backup"
    else
      warn "スキップ: $dest は既に存在します(--force で .bak に退避して上書き)"
      return 0
    fi
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  log "  link: $dest -> $src"
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --force)   FORCE=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help) usage; exit 0 ;;
      *) warn "不明なオプション: $arg"; usage; exit 1 ;;
    esac
  done

  log "dotfiles: $DOTFILES_DIR"
  log "OS:       $(detect_os)"
  log ""

  if [ ! -d "$HOME_SRC" ]; then
    warn "home/ ディレクトリがありません。リンク対象なし。"
    exit 0
  fi

  count=0
  while IFS= read -r -d '' src; do
    rel=${src#"$HOME_SRC"/}
    case "$rel" in
      .gitkeep|*/.gitkeep) continue ;;
    esac
    link_file "$src" "$HOME/$rel"
    count=$((count + 1))
  done < <(find "$HOME_SRC" -type f -print0 | sort -z)

  log ""
  log "完了: ${count} ファイルを処理しました。"
}

main "$@"
