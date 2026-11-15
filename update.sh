#!/usr/bin/env bash
#
# dotfiles update
#
# リポジトリを最新化(git pull)し、続けて home-manager switch(switch.sh)でパッケージ導入と
# home/ 配下の配布を反映する。「リポジトリの状態にこのマシンを揃える」コマンド。
#
#   ./update.sh              # main に切り替えて pull → 反映(更新が無くても反映は実行する。冪等)
#   ./update.sh --current    # 今のブランチのまま pull → 反映(作業ブランチを試すとき)
#   ./update.sh --no-switch  # pull だけ(反映はあとで dotfiles-switch)
#   ./update.sh --dry-run    # pull も反映もせず、どのブランチで更新するかを表示するだけ
#
# pull と反映のあいだで、Node.js のセキュリティリリースに nixpkgs が遅れていないかを調べ、
# 遅れていれば公式バイナリを取り込む(scripts/nodejs-security.sh。git 管理外のファイルに書くだけ)。
#
# 安全設計:
#   - 既定では main(origin の既定のブランチ)に切り替えてから pull する。作業ブランチのまま反映して、
#     途中の状態をそのまま使い続けないため(判断根拠は docs/decisions/update-branch.md)。
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
CURRENT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-switch) NO_SWITCH=1 ;;
    --current) CURRENT=1 ;;
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

# Node.js のセキュリティリリースに nixpkgs が遅れていれば、公式バイナリを取り込む。
# 書くのは git 管理外の nix/nodejs-bin.local.json だけで、実際に入るのは続く switch のとき
# (判断根拠は docs/decisions/nodejs-security-releases.md)。判定できなかったとき
# (nix が無い・オフライン等)は何も表示しない。--dry-run では遅れを表示するだけで書かない。
sync_nodejs_security() {
  local rc=0
  "$DOTFILES_DIR/scripts/nodejs-security.sh" check >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 10 ] || return 0
  log ""
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "Node.js のセキュリティリリースに nixpkgs が追いついていません(dry-run のため取り込みません)。"
    return 0
  fi
  log "Node.js のセキュリティリリースに nixpkgs が追いついていないため、公式バイナリを取り込みます:"
  if ! "$DOTFILES_DIR/scripts/nodejs-security.sh" update 2>&1 | sed 's/^/  /'; then
    warn "取り込みに失敗しました。nixpkgs 版のまま進めます(上の出力を確認してください)。"
  fi
}

# 更新に使うブランチ。既定は origin の既定のブランチ(clone したときの origin/HEAD。無ければ main)
current=$(git -C "$DOTFILES_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [ "$CURRENT" -eq 1 ]; then
  if [ -z "$current" ]; then
    warn "ブランチの上にいない(detached HEAD)ため、--current では更新できません。--current を外すと main で更新します。"
    exit 1
  fi
  branch=$current
else
  branch=$(git -C "$DOTFILES_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  branch=${branch#origin/}
  branch=${branch:-main}
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ "$branch" = "$current" ]; then
    log "[dry-run] $branch を pull して反映します。git pull と反映(switch.sh)はスキップします。"
  else
    log "[dry-run] ${current:-(ブランチなし)} から $branch に切り替えて pull し、反映します。git pull と反映(switch.sh)はスキップします。"
  fi
  sync_nodejs_security
  exit 0
fi

old_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)
if [ "$branch" != "$current" ]; then
  log "${current:-(ブランチなし)} から $branch に切り替えて更新します(今のブランチのまま更新するには --current)。"
  git -C "$DOTFILES_DIR" switch "$branch"
  if [ -n "$current" ]; then
    log "元のブランチに戻るには: git -C $DOTFILES_DIR switch $current"
  fi
fi
git -C "$DOTFILES_DIR" pull --ff-only
new_head=$(git -C "$DOTFILES_DIR" rev-parse HEAD)

if [ "$old_head" != "$new_head" ]; then
  log ""
  log "同梱プラグインも更新する場合(Claude Code / Codex):"
  log "  agent-plugins-setup"
fi

sync_nodejs_security

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
