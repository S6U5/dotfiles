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
  hm=(home-manager)
else
  hm=(nix run "$DOTFILES_DIR/nix#home-manager" --)
fi
cmd=("${hm[@]}" switch --flake "$DOTFILES_DIR/nix#$system" --impure "$@")

# 世代の掃除を聞く(端末で対話中のときだけ)。home-manager は switch のたびに世代を増やし、
# 自分では一つも消さない。古い世代は GC ルートなので nix-collect-garbage でも残り、store が
# 「宣言には無いのに消していない分」で太っていく。戻せなくなる削除なので黙っては行わず、
# 世代が 10 を超え、かつ 30 日より前のものがあるときに限って、人に y/N を聞く。
# 端末でなければ(CI や他スクリプトからの呼び出し)何も聞かず、diskreport の案内に任せる。
# 判断根拠は docs/decisions/storage-hygiene.md。

# 端末の入力バッファに溜まっているキー入力を捨てる。長いビルドの最中に押したキー(矢印や Enter)が
# 残っていると、直後の read がそれを答えとして読んでしまい、質問が待たずに終わるため。
# stty で一時的に「待たずに読む」モードにして読み捨て、元の設定に戻す(macOS の bash 3.2 でも動く書き方)
drain_tty_input() {
  local saved
  saved=$(stty -g </dev/tty 2>/dev/null) || return 0
  if stty -icanon -echo min 0 time 0 </dev/tty 2>/dev/null; then
    dd if=/dev/tty of=/dev/null bs=4096 count=64 2>/dev/null || true
  fi
  stty "$saved" </dev/tty 2>/dev/null || true
  return 0
}

offer_expire_generations() {
  [ -t 0 ] && [ -t 1 ] || return 0
  local dir gens=0 old=0 ans
  for dir in "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles" "/nix/var/nix/profiles/per-user/${USER:-$(id -un)}"; do
    [ -d "$dir" ] || continue
    gens=$((gens + $(find "$dir" -maxdepth 1 -name 'home-manager-*-link' 2>/dev/null | wc -l)))
    old=$((old + $(find "$dir" -maxdepth 1 -name 'home-manager-*-link' -mtime +30 2>/dev/null | wc -l)))
  done
  [ "$gens" -gt 10 ] && [ "$old" -gt 0 ] || return 0
  drain_tty_input
  printf '世代が %d あります(30 日より前が %d)。30 日より前の世代を消して GC しますか?(戻せなくなります)[y/N] ' "$gens" "$old"
  # 答えは端末から直接読む(標準入力がどこかで読まれていても質問が飛ばされないように)
  read -r ans </dev/tty || ans=
  case "$ans" in
    y | Y | yes) ;;
    *)
      log "スキップしました。あとで消すなら: home-manager expire-generations \"-30 days\" && nix-collect-garbage"
      return 0
      ;;
  esac
  "${hm[@]}" expire-generations "-30 days"
  # 消した世代が指していた store パスは誰からも指されなくなったので回収する。
  # -d は付けない(home-manager 以外のプロファイルの世代まで消さない)
  nix-collect-garbage
  if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
    log "空いた分を Windows に返すには: wsl-compact"
  fi
  return 0
}

log "dotfiles switch: 対象 $DOTFILES_DIR($system)"
log "  \$ ${cmd[*]}"
"${cmd[@]}"

# 反映のあとに Nix の容量の状態(世代数・自動 GC の有無)を数行で出す。世代は switch のたびに
# 増え、GC では消えないため、人が打ったこのタイミングで知らせる(タイマーでは走らせない。
# 判断根拠は docs/decisions/storage-hygiene.md)。表示だけで何も消さない。PATH にまだ無い初回
# でも動くよう、リポジトリ内の実体を直接呼ぶ。失敗しても switch の成否には影響させない。
log ""
"$DOTFILES_DIR/home/.local/bin/diskreport" --nix-brief || true
offer_expire_generations || true
