#!/bin/sh
# herdr の pane.agent_status_changed フックから呼ばれ、エージェントが完了(done)・
# 入力待ち(blocked)になったときに Windows のトースト通知を出す。
# 実際の通知処理は notify.ps1(Windows 側の PowerShell で実行)が行う。
#   sh notify.sh          # フックとして実行(HERDR_PLUGIN_EVENT_JSON を読む)
#   sh notify.sh --test   # テスト通知を出す(フォアグラウンド判定をスキップ)
# WSL 以外・powershell.exe が無い環境では何もせず正常終了する。
set -u

plugin_dir=$(cd "$(dirname "$0")" && pwd)

if [ -z "${WSL_DISTRO_NAME:-}" ] && ! grep -qi microsoft /proc/version 2>/dev/null; then
  exit 0
fi

if [ "${1:-}" = "--test" ]; then
  HERDR_PLUGIN_EVENT_JSON='{"data":{"agent_status":"done","display_agent":"herdr","title":"test notification"}}'
  DOTFILES_HERDR_NOTIFY_TEST=1
  export HERDR_PLUGIN_EVENT_JSON DOTFILES_HERDR_NOTIFY_TEST
fi

# 状態が変わるたびに呼ばれるため、PowerShell の起動(1秒弱かかる)の前に文字列一致で絞り込む。
# herdr はイベントを空白なしの JSON で渡す。
case "${HERDR_PLUGIN_EVENT_JSON:-}" in
  *'"agent_status":"done"'* | *'"agent_status":"blocked"'*) ;;
  *) exit 0 ;;
esac

ps_exe=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
if [ ! -x "$ps_exe" ]; then
  ps_exe=$(command -v powershell.exe 2>/dev/null) || {
    echo "powershell.exe が見つかりません(WSL の Windows 相互運用が無効?)" >&2
    exit 0
  }
fi

if ! command -v iconv >/dev/null 2>&1; then
  echo "iconv が見つかりません" >&2
  exit 0
fi

# -EncodedCommand は UTF-16LE の Base64 を要求する(UNC パス上の .ps1 を -File で
# 実行すると実行ポリシーに阻まれうるため、スクリプト本文を直接渡す)。
encoded=$(iconv -f UTF-8 -t UTF-16LE "$plugin_dir/notify.ps1" | base64 | tr -d '\n')

# WSLENV に列挙した環境変数だけが Windows 側のプロセスへ引き継がれる。
WSLENV="${WSLENV:+$WSLENV:}HERDR_PLUGIN_EVENT_JSON:DOTFILES_HERDR_NOTIFY_TEST" \
  "$ps_exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded"
