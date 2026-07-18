# shellcheck shell=sh
# クラウドストレージ連携コマンド。
#   cdod  [名前の一部] — OneDrive(個人用)へ移動
#   cdode [名前の一部] — OneDrive(組織用: 会社・学校アカウント)へ移動
#   cdic  [名前の一部] — iCloud Drive へ移動
#   cdgd  [名前の一部] — Google Drive のフォルダへ移動
# 候補が複数のときは fzf(あれば)か番号選択。パスはハードコードせず実行時に探索する。

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

# iCloud Drive の候補を出力する(macOS 本体 / Windows 版 iCloud)
_icloud_candidates() {
  case "$(uname -s)" in
    Darwin)
      if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
        printf '%s\n' "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
      fi
      ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        find /mnt/c/Users -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r _ic_u; do
          [ -d "$_ic_u/iCloudDrive" ] && printf '%s\n' "$_ic_u/iCloudDrive"
        done
      fi
      ;;
  esac
  return 0
}

# Google Drive の候補を出力する(表示言語によってフォルダ名が違うため英日両方を探す)
_gdrive_candidates() {
  case "$(uname -s)" in
    Darwin)
      find "$HOME/Library/CloudStorage" -mindepth 1 -maxdepth 1 -name 'GoogleDrive*' -type d 2>/dev/null |
        while read -r _gd_d; do
          _gd_found=0
          for _gd_sub in "My Drive" "Shared drives" "マイドライブ" "共有ドライブ"; do
            if [ -d "$_gd_d/$_gd_sub" ]; then
              printf '%s\n' "$_gd_d/$_gd_sub"
              _gd_found=1
            fi
          done
          [ "$_gd_found" -eq 0 ] && printf '%s\n' "$_gd_d"
        done
      ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        # ミラーリング型: ユーザーフォルダ配下の「Google Drive」
        find /mnt/c/Users -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r _gd_u; do
          find "$_gd_u" -mindepth 1 -maxdepth 1 -name 'Google Drive*' -type d 2>/dev/null
        done
        # ストリーミング型: 仮想ドライブ(G: 等)が WSL にマウントされていれば
        find /mnt -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r _gd_m; do
          for _gd_sub in "My Drive" "マイドライブ"; do
            [ -d "$_gd_m/$_gd_sub" ] && printf '%s\n' "$_gd_m/$_gd_sub"
          done
        done
      fi
      ;;
  esac
  return 0
}

# OneDrive の候補を個人用/組織用に選り分ける($1: personal または enterprise)
# 個人用はフォルダ名が「OneDrive」または「OneDrive-Personal」、組織用は「OneDrive-会社名」等
_onedrive_filtered() {
  _onedrive_candidates | while read -r _od_line; do
    case "${_od_line##*/}" in
      OneDrive | OneDrive-Personal | "OneDrive - Personal")
        [ "$1" = personal ] && printf '%s\n' "$_od_line"
        ;;
      *)
        [ "$1" = enterprise ] && printf '%s\n' "$_od_line"
        ;;
    esac
  done
  return 0
}

# OneDrive(個人用)へ移動する
cdod() {
  _dotfiles_cd_from_list "$(_onedrive_filtered personal)" "${1:-}" cdod
}

# OneDrive(組織用: 会社・学校アカウント)へ移動する
cdode() {
  _dotfiles_cd_from_list "$(_onedrive_filtered enterprise)" "${1:-}" cdode
}

# iCloud Drive へ移動する
cdic() {
  _dotfiles_cd_from_list "$(_icloud_candidates)" "${1:-}" cdic
}

# Google Drive のフォルダへ移動する
cdgd() {
  _dotfiles_cd_from_list "$(_gdrive_candidates)" "${1:-}" cdgd
}
