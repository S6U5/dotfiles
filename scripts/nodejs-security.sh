#!/usr/bin/env bash
#
# Node.js のセキュリティリリースに、nixpkgs の nodejs が追いついているかを調べる。
# 遅れているあいだは nodejs.org の公式ビルド済みバイナリで補うため、その固定値
# (nix/nodejs-bin.json)を更新する(判断根拠は docs/decisions/nodejs-security-releases.md)。
#
#   ./scripts/nodejs-security.sh check   # 遅れていれば 10 で終了する(読み取りのみ。CI と update.sh 用)
#   ./scripts/nodejs-security.sh update  # 遅れていれば nix/nodejs-bin.json を書き換える
#
# 比べる対象は、flake.lock に固定された nixpkgs の nodejs と同じメジャーの、
# nodejs.org で最新のセキュリティリリース。nix/nodejs-bin.json の方が新しければ
# それが使われている(nix/home.nix 参照)ので、遅れていない扱いになる。
# update はハッシュを Node.js 公式のリリース鍵による署名で検証してから書き込む
# (鍵は nodejs.org とは別経路の nodejs/release-keys から取る)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DOTFILES_DIR"

PIN_FILE=nix/nodejs-bin.json
DIST_URL=https://nodejs.org/dist
KEYRING_URL=https://raw.githubusercontent.com/nodejs/release-keys/HEAD/gpg-only-active-keys/pubring.kbx

usage() {
  echo "使い方: $0 check|update" >&2
  exit 2
}

mode=${1:-}
case "$mode" in
  check | update) ;;
  *) usage ;;
esac

for cmd in nix curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "nodejs-security: $cmd が見つかりません。" >&2
    exit 1
  fi
done

nix_eval() {
  nix --extra-experimental-features 'nix-command flakes' eval "$@"
}

# a >= b なら 0 を返す
version_at_least() {
  [ "$(nix_eval --raw --expr "toString (builtins.compareVersions \"$1\" \"$2\")")" != "-1" ]
}

valid_version() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nixpkgs_version=$(nix_eval --raw --inputs-from ./nix nixpkgs#nodejs.version)
pin_version=$(nix_eval --raw --impure --expr "(builtins.fromJSON (builtins.readFile \"$DOTFILES_DIR/$PIN_FILE\")).version")
major=${nixpkgs_version%%.*}

curl -fsSL "$DIST_URL/index.json" -o "$tmp/index.json"
# index.json は新しい順に並んでいる。同じメジャーで security が true の最初のものを取る
target=$(nix_eval --raw --impure --expr "
  let
    releases = builtins.fromJSON (builtins.readFile \"$tmp/index.json\");
    hits = builtins.filter
      (r: r.security && builtins.match \"v$major\\\\..*\" r.version != null)
      releases;
  in if hits == [ ] then \"\" else builtins.substring 1 (-1) (builtins.head hits).version
")

if [ -z "$target" ]; then
  echo "nodejs-security: Node.js $major.x のセキュリティリリースが見つかりません。" >&2
  exit 1
fi
if ! valid_version "$target"; then
  echo "nodejs-security: 想定外のバージョン表記です: $target" >&2
  exit 1
fi

echo "nixpkgs の nodejs: $nixpkgs_version"
echo "$PIN_FILE: $pin_version"
echo "最新のセキュリティリリース($major.x): $target"

if version_at_least "$nixpkgs_version" "$target" || version_at_least "$pin_version" "$target"; then
  echo "nodejs-security: 対応済みです。"
  exit 0
fi

if [ "$mode" = check ]; then
  echo "nodejs-security: nixpkgs の nodejs が $target に追いついていません。" >&2
  echo "nodejs-security: ./scripts/nodejs-security.sh update を実行して PR にしてください。" >&2
  # 判定できなかった場合(ネットワーク不調等)の非0と区別するため、遅れは専用の値で返す
  exit 10
fi

if ! command -v gpgv >/dev/null 2>&1; then
  echo "nodejs-security: 署名の検証に gpgv が必要です(検証なしでは書き込みません)。" >&2
  exit 1
fi

curl -fsSL "$KEYRING_URL" -o "$tmp/pubring.kbx"
curl -fsSL "$DIST_URL/v$target/SHASUMS256.txt.asc" -o "$tmp/SHASUMS256.txt.asc"
# SHASUMS256.txt.asc はクリア署名なので、検証を通った本文だけを使う
if ! gpgv --keyring "$tmp/pubring.kbx" --output "$tmp/verified-sums.txt" "$tmp/SHASUMS256.txt.asc"; then
  echo "nodejs-security: SHASUMS256.txt の署名を検証できませんでした。" >&2
  exit 1
fi

sri_hash() {
  local hex
  hex=$(awk -v f="node-v$target-$1.tar.xz" '$2 == f { print $1 }' "$tmp/verified-sums.txt")
  if ! printf '%s\n' "$hex" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "nodejs-security: node-v$target-$1.tar.xz のハッシュが見つかりません。" >&2
    exit 1
  fi
  nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$hex"
}

# システム名は nix/nodejs-bin.nix の対応表と揃える
x86_64_linux=$(sri_hash linux-x64)
aarch64_linux=$(sri_hash linux-arm64)
aarch64_darwin=$(sri_hash darwin-arm64)

cat >"$PIN_FILE" <<EOF
{
  "version": "$target",
  "hashes": {
    "x86_64-linux": "$x86_64_linux",
    "aarch64-linux": "$aarch64_linux",
    "aarch64-darwin": "$aarch64_darwin"
  }
}
EOF

echo "nodejs-security: $PIN_FILE を $target に更新しました。"
echo "nodejs-security: コミットして PR にし、マージ後に home-manager switch で反映してください。"
