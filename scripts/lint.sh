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
done < <(git ls-files -- '*.sh' '.githooks/*' 'home/.local/bin/*' 'home/.config/bash/*')

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

# `$名前` のすぐ後ろに日本語などの ASCII 以外の文字が続くと、macOS の bash 3.2(/bin/sh も)と zsh は
# UTF-8 のロケールでその文字の一部まで変数名として読み、set -u なら「unbound variable」で止まる。
# これは shellcheck では見つからないため、ここで探して `${名前}` と書くよう促す(コメント行は除く。
# zsh の設定と nix/*.nix の中のシェルの断片も見る)
mb_files=("${files[@]}")
while IFS= read -r f; do
  mb_files+=("$f")
done < <(git ls-files -- 'home/.config/zsh/*' 'nix/*.nix')
mb_pattern=$(printf '\\$[A-Za-z_][A-Za-z0-9_]*[\200-\377]')
if mb_hits=$(LC_ALL=C grep -nE "$mb_pattern" "${mb_files[@]}" | LC_ALL=C grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'); then
  echo "$mb_hits" >&2
  echo "NG: \$名前 のすぐ後ろに ASCII 以外の文字があります。\${名前} と書いてください(bash 3.2 と zsh が変数名の一部として読むため)。" >&2
  status=1
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
