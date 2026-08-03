#!/usr/bin/env bash
#
# home/ や templates/ に取り込む「候補」ファイル・ディレクトリ(リポジトリの外、
# 例: ~/Configs や ~/.config の実機設定)を対象に、個人情報・機密の混入を検出する。
# pre-commit フック(.githooks/pre-commit)はステージ済みの差分しか見られないため、
# まだリポジトリに入れていない外部ファイルはこのスクリプトで先に検査する。
#
# 検出は機械的なパターンマッチのみ。プロジェクト名・会社名・個人の生活が
# 分かる記述などは自動検出できないため、このスクリプトが「クリーン」と
# 判定しても、プロンプト系ファイル(*.md 等)は必ず全文を目視で確認すること
# (CLAUDE.md の最重要ルール)。
#
# 使い方: scan.sh <ファイルまたはディレクトリ> [...]
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "使い方: $0 <ファイルまたはディレクトリ> [...]" >&2
  exit 1
fi

found=0

# --- 機密情報らしきパターン(.githooks/pre-commit と同種。二重管理だが
#     対象がリポジトリ外のファイルのため gitleaks/pre-commit の対象外) ---
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{22,}'
  'gho_[A-Za-z0-9]{36}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'sk-ant-[A-Za-z0-9_-]{20,}'
  'sk-[A-Za-z0-9]{32,}'
  'AIza[0-9A-Za-z_-]{35}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '(api[_-]?key|api[_-]?secret|access[_-]?token|client[_-]?secret|password)[[:space:]"'"'"']*[=:][[:space:]"'"'"']*[A-Za-z0-9_/+.-]{16,}'
)

# --- 実ユーザー名入りの絶対パス(このマシンの $USER で判定) ---
me="${USER:-$(id -un)}"
PATH_PATTERNS=(
  "/Users/${me}(/|$)"
  "/home/${me}(/|$)"
  "C:\\\\\\\\Users\\\\\\\\${me}(\\\\\\\\|$)"
)

# --- メールアドレス ---
EMAIL_PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

scan_file() {
  file="$1"
  # バイナリファイルはスキップ
  if ! grep -Iq . "$file" 2>/dev/null; then
    return
  fi

  for pat in "${SECRET_PATTERNS[@]}"; do
    matches=$(grep -Eino -e "$pat" "$file" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      echo "[機密疑い] $file"
      printf '%s\n' "$matches" | sed 's/^/    /'
      found=1
    fi
  done

  for pat in "${PATH_PATTERNS[@]}"; do
    matches=$(grep -Eino -e "$pat" "$file" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      echo "[実ユーザー名パス] $file"
      printf '%s\n' "$matches" | sed 's/^/    /'
      found=1
    fi
  done

  matches=$(grep -Eino -e "$EMAIL_PATTERN" "$file" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "[メールアドレス疑い] $file"
    printf '%s\n' "$matches" | sed 's/^/    /'
    found=1
  fi
}

for target in "$@"; do
  if [ -d "$target" ]; then
    while IFS= read -r -d '' file; do
      scan_file "$file"
    done < <(find "$target" -type f -print0)
  elif [ -f "$target" ]; then
    scan_file "$target"
  else
    echo "警告: 見つかりません: $target" >&2
  fi
done

if [ "$found" -eq 0 ]; then
  echo "機械的なパターン検出では問題は見つかりませんでした。"
  echo "ただし、プロジェクト名・会社名・個人の生活が分かる記述などは自動検出できません。"
  echo "特にプロンプト系ファイル(*.md 等)は必ず全文を目視で確認してください。"
fi

exit 0
