#!/usr/bin/env bash
#
# パッケージ導入スクリプト。OS を判定して対応するリストを導入する。
#
#   macOS       -> packages/Brewfile(brew bundle)
#   Debian 系   -> packages/apt.txt(apt-get。sudo を使う)
#
# 方針(CLAUDE.md 参照):
#   - 明示的に実行したときだけ動く。install.sh / update.sh からは呼ばれない。
#   - 冪等(導入済みのものはそのまま)。
#
# 使い方:
#   ./packages/install.sh            # 導入
#   ./packages/install.sh --dry-run  # 何が導入されるかの表示のみ
set -euo pipefail

PACKAGES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "不明なオプション: $arg" >&2
      exit 1
      ;;
  esac
done

install_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew が見つかりません。https://brew.sh の手順で導入してから再実行してください。" >&2
    exit 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] brew bundle --file $PACKAGES_DIR/Brewfile"
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --file "$PACKAGES_DIR/Brewfile" | sed 's/^/  /'
    return 0
  fi
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file "$PACKAGES_DIR/Brewfile"
}

install_apt() {
  # リストからコメントと空行を除き、行頭のパッケージ名だけ取り出す
  pkgs=()
  while IFS= read -r name; do
    pkgs+=("$name")
  done < <(sed -e 's/#.*//' -e 's/[[:space:]].*//' "$PACKAGES_DIR/apt.txt" | grep -v '^$')

  if [ "${#pkgs[@]}" -eq 0 ]; then
    echo "apt.txt に導入対象がありません。"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] sudo apt-get install: ${pkgs[*]}"
    echo "[dry-run] (この環境の apt リポジトリに無いパッケージは実行時にスキップされます)"
    return 0
  fi
  sudo apt-get update

  # リポジトリに無いパッケージ(古い Ubuntu の shfmt / zoxide 等)が
  # 一括 install 全体を失敗させないよう、警告してスキップする
  available=()
  for pkg in "${pkgs[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      echo "WARN: スキップ: $pkg(この環境の apt リポジトリにありません)" >&2
    fi
  done
  if [ "${#available[@]}" -eq 0 ]; then
    echo "導入可能なパッケージがありません。"
    return 0
  fi
  sudo apt-get install -y "${available[@]}"
}

case "$(uname -s)" in
  Darwin)
    install_brew
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      install_apt
    else
      echo "対応するパッケージマネージャが見つかりません(現在 apt のみ対応。dnf 等は必要になったら追加)。" >&2
      exit 1
    fi
    ;;
  *)
    echo "未対応の OS です: $(uname -s)" >&2
    exit 1
    ;;
esac

echo "完了。"
