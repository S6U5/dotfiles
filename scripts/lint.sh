#!/usr/bin/env bash
#
# lint とフォーマットチェック。CI と pre-commit フックの両方から使う。
#
#   シェル            shellcheck(lint)/ shfmt(フォーマット)
#   Lua               stylua(フォーマット)
#   Nix               nixfmt(フォーマット)
#   GitHub Actions    actionlint(lint)
#
#   ./scripts/lint.sh        # チェックのみ(問題があれば非0で終了)
#   ./scripts/lint.sh --fix  # フォーマットを自動修正(shfmt / stylua / nixfmt)
#
# ツールが無い環境では警告してスキップする。CI(環境変数 CI がある)では、ツールが無いことも
# 失敗にする(入れ忘れで検査が黙って飛ばされないようにするため)。ツールはどれも nix/home.nix で
# 入るもので、CI も nix/flake.lock の同じ版を使う(判断根拠は docs/decisions/lint-tools.md)。
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

# ツールがあれば 0。無ければ警告して非0を返す(CI ではさらに、全体を失敗にする)
have() {
  command -v "$1" >/dev/null 2>&1 && return 0
  if [ -n "${CI:-}" ]; then
    echo "NG: $1 が見つかりません(CI では lint のツールをすべて入れてください)。" >&2
    status=1
  else
    echo "WARN: $1 が見つからないためスキップします。" >&2
  fi
  return 1
}

if have shellcheck; then
  if ! shellcheck "${files[@]}"; then
    status=1
  fi
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

if have shfmt; then
  if [ "$FIX" -eq 1 ]; then
    shfmt -w -i 2 -ci "${files[@]}"
  elif ! shfmt -d -i 2 -ci "${files[@]}"; then
    echo "HINT: ./scripts/lint.sh --fix で自動修正できます。" >&2
    status=1
  fi
fi

# git 管理下のファイルを、パターンで配列 list に集める
collect() {
  list=()
  while IFS= read -r f; do
    list+=("$f")
  done < <(git ls-files -- "$@")
}

# Lua(Neovim / WezTerm の設定)。書式は Neovim 側の stylua.toml に揃える
# (stylua は実行した場所から設定を探すため、どこで動かしても同じになるよう明示して渡す)
collect '*.lua'
if [ "${#list[@]}" -gt 0 ] && have stylua; then
  stylua_args=(--config-path home/.config/nvim/stylua.toml)
  if [ "$FIX" -eq 1 ]; then
    stylua "${stylua_args[@]}" "${list[@]}"
  elif ! stylua --check "${stylua_args[@]}" "${list[@]}"; then
    echo "HINT: ./scripts/lint.sh --fix で自動修正できます。" >&2
    status=1
  fi
fi

# Nix
collect '*.nix'
if [ "${#list[@]}" -gt 0 ] && have nixfmt; then
  if [ "$FIX" -eq 1 ]; then
    nixfmt "${list[@]}"
  elif ! nixfmt --check "${list[@]}"; then
    echo "HINT: ./scripts/lint.sh --fix で自動修正できます。" >&2
    status=1
  fi
fi

# GitHub Actions のワークフロー(式・キーの誤り。run: の中のシェルは、shellcheck があれば
# actionlint がそれも通す)
collect '.github/workflows/*.yml' '.github/workflows/*.yaml'
if [ "${#list[@]}" -gt 0 ] && have actionlint; then
  if ! actionlint "${list[@]}"; then
    status=1
  fi
fi

exit "$status"
