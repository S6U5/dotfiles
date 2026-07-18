# shellcheck shell=sh
# WSL の Windows 連携コマンド(移動系)。
#   cdwin [サブフォルダ] — Windows のユーザーフォルダ(C:\Users\<名前>)へ移動。
#                          例: cdwin Downloads / cdwin Desktop
# WSL 以外では親切メッセージを出して何もしない(CLAUDE.md「OS 固有コマンド」参照)。

cdwin() {
  if [ -z "${WSL_DISTRO_NAME:-}" ] && ! grep -qi microsoft /proc/version 2>/dev/null; then
    echo "cdwin: WSL 専用のコマンドです(この環境では何もしません)" >&2
    return 0
  fi
  if ! command -v cmd.exe >/dev/null 2>&1; then
    echo "cdwin: cmd.exe が見つかりません(Windows 連携が無効?)" >&2
    return 0
  fi

  # Windows のユーザーフォルダをハードコードせず実行時に取得する
  _cdwin_prof=$(
    cd /mnt/c 2>/dev/null || cd /
    cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r'
  )
  _cdwin_dir=$(wslpath -u "$_cdwin_prof" 2>/dev/null)
  if [ -z "$_cdwin_dir" ] || [ ! -d "$_cdwin_dir" ]; then
    echo "cdwin: Windows のユーザーフォルダを特定できませんでした" >&2
    unset _cdwin_prof _cdwin_dir
    return 1
  fi

  if [ -n "${1:-}" ]; then
    _cdwin_target=""
    # Downloads / Desktop などの「既知のフォルダ」は場所が移動されている可能性があるため、
    # まず Windows に正式な現在地を照会する(shell: 名。移動済みでも正しい場所が返る)。
    # 記号入りの引数は照会せず、通常のサブフォルダ名として扱う
    case "$1" in
      *[!A-Za-z0-9_-]*) : ;;
      *)
        _cdwin_known=$(
          cd /mnt/c 2>/dev/null || cd /
          powershell.exe -NoProfile -Command \
            "(New-Object -ComObject Shell.Application).NameSpace('shell:$1').Self.Path" 2>/dev/null | tr -d '\r'
        )
        case "$_cdwin_known" in
          [A-Za-z]:\\*) _cdwin_target=$(wslpath -u "$_cdwin_known" 2>/dev/null) ;;
        esac
        ;;
    esac
    # 既知フォルダとして解決できなければ、ユーザーフォルダ直下の名前として扱う
    if [ -z "$_cdwin_target" ] || [ ! -d "$_cdwin_target" ]; then
      _cdwin_target="$_cdwin_dir/$1"
    fi
    if [ ! -d "$_cdwin_target" ]; then
      echo "cdwin: フォルダがありません: $1" >&2
      unset _cdwin_prof _cdwin_dir _cdwin_target _cdwin_known
      return 1
    fi
    _cdwin_dir=$_cdwin_target
  fi

  cd "$_cdwin_dir" || {
    unset _cdwin_prof _cdwin_dir _cdwin_target _cdwin_known
    return 1
  }
  unset _cdwin_prof _cdwin_dir _cdwin_target _cdwin_known
}
