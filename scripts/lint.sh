#!/usr/bin/env bash
#
# シェルスクリプトの lint(shellcheck)とフォーマットチェック(shfmt)。
# CI と pre-commit フックの両方から使う。
#
#   ./scripts/lint.sh        # チェックのみ(問題があれば非0で終了)
#   ./scripts/lint.sh --fix  # shfmt でフォーマットを自動修正
#
# ツールが無い環境では警告してスキップする(CI 側では必ずインストールする)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DOTFILES_DIR"

FIX=0
[ "${1:-}" = "--fix" ] && FIX=1

# 対象: git 管理下の *.sh と .githooks/ 以下、home/.local/bin/ の自作コマンド
files=()
while IFS= read -r f; do
  files+=("$f")
done < <(git ls-files -- '*.sh' '.githooks/*' 'home/.local/bin/*' 'home/.config/bash/*' 'home/.bashrc' 'home/.bash_profile')

if [ "${#files[@]}" -eq 0 ]; then
  echo "lint 対象ファイルがありません。"
  exit 0
fi

status=0

if command -v shellcheck >/dev/null 2>&1; then
  if ! shellcheck "${files[@]}"; then
    status=1
  fi
else
  echo "WARN: shellcheck が見つからないためスキップします。" >&2
fi

if command -v shfmt >/dev/null 2>&1; then
  if [ "$FIX" -eq 1 ]; then
    shfmt -w -i 2 -ci "${files[@]}"
  elif ! shfmt -d -i 2 -ci "${files[@]}"; then
    echo "HINT: ./scripts/lint.sh --fix で自動修正できます。" >&2
    status=1
  fi
else
  echo "WARN: shfmt が見つからないためスキップします。" >&2
fi

exit "$status"
