#!/usr/bin/env bash
#
# dotfiles update
#
# リポジトリを最新化(git pull)し、続けて home-manager switch(switch.sh)でパッケージ導入と
# home/ 配下の配布を反映する。「リポジトリの状態にこのマシンを揃える」コマンド。
#
#   ./update.sh              # pull → 反映(更新が無くても反映は実行する。冪等)
#   ./update.sh --no-switch  # pull だけ(反映はあとで dotfiles-switch)
#   ./update.sh --dry-run    # pull も反映もせず状態表示のみ
#
# 安全設計:
#   - 未コミットのローカル変更(未追跡ファイル含む)があれば中断する(上書き事故防止)。
#   - pull は fast-forward のみ(--ff-only)。勝手にマージコミットを作らない。
#   - 反映はこのコマンドを明示実行したときだけ走る(シェル起動時やタイマーで勝手に走る
#     仕組みは作らない。判断根拠は docs/decisions/package-management.md、pull と反映を
#     1コマンドにした理由は docs/decisions/home-manager-switch-invocation.md 参照)。
#
# home/ 配下は home-manager がリポジトリの実体へ直接シンボリックリンクするため、pull の
# 時点で既存ファイルの変更は反映済みになる。新規ファイルのリンク・パッケージの増減・
# activation の処理だけが switch 待ちになるので、pull だけで止めると新旧が混ざる。
# それを避けるため既定で続けて反映する。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

DRY_RUN=0
NO_SWITCH=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-switch) NO_SWITCH=1 ;;
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
  log "[dry-run] git pull と反映(switch.sh)はスキップします。"
  exit 0
fi

old_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
git -C "$DOTFILES_DIR" pull --ff-only
new_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)

if [ "$old_head" != "$new_head" ]; then
  log ""
  log "同梱プラグインも更新する場合(Claude Code / Codex):"
  log "  agent-plugins-setup"
fi

if [ "$NO_SWITCH" -eq 1 ]; then
  log ""
  log "反映は後で実行してください:"
  log "  dotfiles-switch   (または $DOTFILES_DIR/switch.sh)"
  exit 0
fi

log ""
if ! "$DOTFILES_DIR/switch.sh"; then
  warn "反映(home-manager switch)に失敗しました。既存ファイルとの衝突なら、退避して上書きする次のコマンドで再実行できます:"
  warn "  dotfiles-switch -b bak   (または $DOTFILES_DIR/switch.sh -b bak)"
  exit 1
fi
