#!/usr/bin/env bash
#
# nix/home.nix の home.packages で宣言したツールが、実際にはNix以外の場所
# (OS標準/Homebrew/apt等/手動配置)に上書きされていないかを検出する。
# 検出・分類のみを行い、削除などの破壊的操作は一切行わない。
#
#   ./check-duplicates.sh [dotfilesリポジトリのパス。省略時は自動解決]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=${1:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}
HOME_NIX="$DOTFILES_DIR/nix/home.nix"

if [ ! -f "$HOME_NIX" ]; then
  echo "エラー: $HOME_NIX が見つかりません。dotfilesリポジトリのパスを引数で指定してください。" >&2
  exit 1
fi

# nixpkgsの属性名と実際のバイナリ名が異なるものの例外マッピング。
# 新しいツールを追加してこの対応表に無いものは、パッケージ名をそのまま
# コマンド名とみなす(外れる場合は結果が「要手動確認」になるので気づける)。
cmd_for_pkg() {
  case "$1" in
    ripgrep) echo rg ;;
    neovim) echo nvim ;;
    *) echo "$1" ;;
  esac
}

# realpath相当をできるだけポータブルに解決する(macOS標準readlinkは-f非対応の場合がある)。
resolve_path() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1" 2>/dev/null && return
  fi
  if readlink -f "$1" >/dev/null 2>&1; then
    readlink -f "$1"
    return
  fi
  python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$1" 2>/dev/null || echo "$1"
}

# home.packages = with pkgs; [ ... ]; の中身を1行1パッケージで抽出する。
packages=()
while IFS= read -r line; do
  packages+=("$line")
done < <(
  awk '/home\.packages[[:space:]]*=/{flag=1; next} flag && /\]/{flag=0} flag' "$HOME_NIX" |
    sed -E 's/#.*//' |
    tr -d ' \t' |
    grep -v '^$'
)

nix_profile="$HOME/.nix-profile/bin"
os=$(uname -s)

printf '%-22s %-10s %-45s %-24s %s\n' "パッケージ" "コマンド" "実際に解決されるパス" "分類" "備考"
printf -- '-%.0s' $(seq 1 130)
echo

for pkg in "${packages[@]}"; do
  # "nerd-fonts.jetbrains-mono" のような属性パス(実行コマンドを持たない)はスキップ。
  case "$pkg" in
    *.*)
      printf '%-22s %-10s %-45s %-24s %s\n' "$pkg" "-" "-" "スキップ" "実行コマンドを持たない属性(フォント等)"
      continue
      ;;
  esac

  cmd=$(cmd_for_pkg "$pkg")
  nix_path="$nix_profile/$cmd"

  if [ ! -e "$nix_path" ]; then
    printf '%-22s %-10s %-45s %-24s %s\n' "$pkg" "$cmd" "-" "要手動確認" "$nix_profile側にコマンドが無い(コマンド名推測ミスの可能性)"
    continue
  fi

  actual_path=$(command -v "$cmd" 2>/dev/null || true)
  if [ -z "$actual_path" ]; then
    printf '%-22s %-10s %-45s %-24s %s\n' "$pkg" "$cmd" "(見つからない)" "要手動確認" "PATH上にコマンドが無い"
    continue
  fi

  nix_real=$(resolve_path "$nix_path")
  actual_real=$(resolve_path "$actual_path")

  if [ "$nix_real" = "$actual_real" ]; then
    printf '%-22s %-10s %-45s %-24s %s\n' "$pkg" "$cmd" "$actual_path" "OK" "Nix版がそのまま使われている"
    continue
  fi

  # ここに来た時点で「Nix以外の何か」に上書きされている。出どころを分類する。
  category="不明"
  note="要手動確認"

  case "$actual_path" in
    /usr/bin/* | /bin/* | /usr/sbin/* | /sbin/*)
      if [ "$os" = "Darwin" ]; then
        category="OS標準(保持)"
        note="macOS標準搭載の可能性が高い。削除しない。"
      elif command -v dpkg >/dev/null 2>&1 && dpkg -S "$actual_path" >/dev/null 2>&1; then
        owner_pkg=$(dpkg -S "$actual_path" 2>/dev/null | head -1 | cut -d: -f1) || owner_pkg="?"
        essential=$(dpkg-query -W -f='${Essential}' "$owner_pkg" 2>/dev/null || echo "")
        if [ "$essential" = "yes" ]; then
          category="OS標準(保持)"
          note="dpkgのessentialパッケージ($owner_pkg)由来。削除しない。"
        else
          category="パッケージ管理(削除候補)"
          note="apt管理下のパッケージ($owner_pkg)。削除候補(要apt remove判断)。"
        fi
      else
        category="不明"
        note="OS標準かどうか判定できなかった。手動確認推奨。"
      fi
      ;;
    /opt/homebrew/* | /usr/local/Cellar/* | /usr/local/bin/*)
      category="Homebrew(削除候補)"
      note="brew uninstall $pkg で削除できる可能性。"
      ;;
    "$HOME"/.local/bin/*)
      link_target=""
      if [ -L "$actual_path" ]; then
        link_target=$(readlink "$actual_path" 2>/dev/null || echo "")
      fi
      case "$link_target" in
        */home/.local/bin/*)
          category="自作コマンド(要目視確認)"
          note="dotfilesのhome/.local/bin/由来。同名の別ツールの可能性。削除しない。"
          ;;
        *)
          category="手動配置(削除候補)"
          note="git管理外の手動配置バイナリ。rm $actual_path で削除できる可能性。"
          ;;
      esac
      ;;
    *)
      category="不明"
      note="どの経路にも当てはまらない。手動確認推奨。"
      ;;
  esac

  # バージョン比較(取得できる範囲でベストエフォート)。
  nix_ver=$("$nix_path" --version 2>/dev/null | head -1) || nix_ver="?"
  actual_ver=$("$actual_path" --version 2>/dev/null | head -1) || actual_ver="?"
  if [ "$nix_ver" != "$actual_ver" ]; then
    note="$note ⚠バージョン不一致(Nix: $nix_ver / 実際: $actual_ver)"
  fi

  printf '%-22s %-10s %-45s %-24s %s\n' "$pkg" "$cmd" "$actual_path" "$category" "$note"
done
