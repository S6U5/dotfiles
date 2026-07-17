# shellcheck shell=bash
# Office 系コマンドの補完: 各アプリで開ける形式のみ、1ファイルまで(2つ目以降は補完しない)

_office_complete() {
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

# teams はファイル指定なし(起動のみ)のため、登録して「何も補完しない」ようにする
for _office_cmd in word excel powerpoint outlook onenote teams; do
  complete -o filenames -F _office_complete "$_office_cmd"
done
unset _office_cmd
