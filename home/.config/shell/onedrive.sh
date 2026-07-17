# shellcheck shell=sh
# OneDrive 連携コマンド。
#   cdod [名前の一部] — OneDrive のフォルダへ移動する
# 個人用と組織用など複数ある場合は fzf(あれば)か番号選択(共通ヘルパー _dotfiles_pick_line)。

# OneDrive フォルダの候補(1行1件)を OS ごとに出力する
_onedrive_candidates() {
  case "$(uname -s)" in
    Darwin)
      find "$HOME/Library/CloudStorage" -mindepth 1 -maxdepth 1 -name 'OneDrive*' -type d 2>/dev/null
      [ -d "$HOME/OneDrive" ] && printf '%s\n' "$HOME/OneDrive"
      ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL: Windows 側の OneDrive フォルダ(個人用・組織用)を探す
        find /mnt/c/Users -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r _od_u; do
          find "$_od_u" -mindepth 1 -maxdepth 1 -name 'OneDrive*' -type d 2>/dev/null
        done
      else
        [ -d "$HOME/OneDrive" ] && printf '%s\n' "$HOME/OneDrive"
      fi
      ;;
  esac
  return 0
}

# OneDrive のフォルダへ移動する
cdod() {
  _cdod_list=$(_onedrive_candidates)
  if [ -z "$_cdod_list" ]; then
    echo "cdod: OneDrive フォルダが見つかりません(未設定?)" >&2
    return 0
  fi
  _cdod_t=$(_dotfiles_pick_line "$_cdod_list" "${1:-}" OneDrive) || {
    echo "cdod: 該当する OneDrive フォルダがありません${1:+(絞り込み: $1)}" >&2
    unset _cdod_list _cdod_t
    return 1
  }
  if [ -z "$_cdod_t" ]; then
    unset _cdod_list _cdod_t
    return 0
  fi
  cd "$_cdod_t" || {
    unset _cdod_list _cdod_t
    return 1
  }
  unset _cdod_list _cdod_t
}