# shellcheck shell=bash
# アプリ起動系コマンドの補完: 各アプリで開ける形式のみ、1ファイルまで(2つ目以降は補完しない)

_apps_complete() {
  COMPREPLY=()
  [ "$COMP_CWORD" -eq 1 ] || return 0
  local cur=${COMP_WORDS[COMP_CWORD]}
  local exts
  case "${COMP_WORDS[0]}" in
    teams) return 0 ;; # 起動のみ(ファイル指定なし)なので何も補完しない
    word) exts='doc docx docm dot dotx dotm rtf odt txt' ;;
    excel) exts='xls xlsx xlsm xlt xltx xltm csv' ;;
    powerpoint) exts='ppt pptx pptm pot potx potm pps ppsx odp' ;;
    outlook) exts='msg eml ics' ;;
    onenote) exts='one onepkg' ;;
    fusion360) exts='f3d f3z step stp igs iges stl obj dxf' ;;
    *) exts='' ;;
  esac
  local f e keep
  while IFS= read -r f; do
    if [ -d "$f" ]; then
      COMPREPLY+=("$f")
    else
      keep=0
      for e in $exts; do
        case "$f" in
          *."$e") keep=1 ;;
        esac
      done
      [ "$keep" -eq 1 ] && COMPREPLY+=("$f")
    fi
  done < <(compgen -f -- "$cur")
}

for _apps_cmd in word excel powerpoint outlook onenote teams fusion360; do
  complete -o filenames -F _apps_complete "$_apps_cmd"
done
unset _apps_cmd
