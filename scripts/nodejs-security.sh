#!/usr/bin/env bash
#
# Node.js のセキュリティリリースに、nixpkgs の nodejs が追いついているかを調べる。
# 遅れているあいだは nodejs.org の公式ビルド済みバイナリで補うため、その固定値を
# git 管理外の nix/nodejs-bin.local.json に書く(判断根拠は docs/decisions/nodejs-security-releases.md)。
#
#   ./scripts/nodejs-security.sh status  # 今どちらの Node か、次の switch でどちらが入るかを表示する
#   ./scripts/nodejs-security.sh check   # 遅れていれば 10 で終了する(読み取りのみ)
#   ./scripts/nodejs-security.sh update  # 遅れていれば nix/nodejs-bin.local.json を書く
#
# update.sh(dotfiles-update)が pull と switch のあいだに check → update の順で呼ぶので、
# 普段は手で実行しなくてよい。比べる対象は、flake.lock に固定された nixpkgs の nodejs と
# 同じメジャーの、nodejs.org で最新のセキュリティリリース。nix/nodejs-bin.local.json の
# 方が新しければそれが使われる(nix/home.nix 参照)ので、遅れていない扱いになる。
# update はハッシュを Node.js 公式のリリース鍵による署名で検証してから書き込む
# (鍵は nodejs.org とは別経路の nodejs/release-keys から取る)。
# DOTFILES_NODEJS=nixpkgs のときは nixpkgs 版に固定しているので、check / update は何もしない。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DOTFILES_DIR"

PIN_FILE=nix/nodejs-bin.local.json
DIST_URL=https://nodejs.org/dist
KEYRING_URL=https://raw.githubusercontent.com/nodejs/release-keys/HEAD/gpg-only-active-keys/pubring.kbx

usage() {
  echo "使い方: $0 status|check|update" >&2
  exit 2
}

mode=${1:-}
case "$mode" in
  status | check | update) ;;
  *) usage ;;
esac

node_mode=${DOTFILES_NODEJS:-auto}
case "$node_mode" in
  auto | nixpkgs) ;;
  *)
    echo "nodejs-security: DOTFILES_NODEJS は auto か nixpkgs を指定してください(指定値: $node_mode)" >&2
    exit 2
    ;;
esac

if [ "$node_mode" = nixpkgs ] && [ "$mode" != status ]; then
  echo "nodejs-security: DOTFILES_NODEJS=nixpkgs のため、nixpkgs 版に固定しています(何もしません)。"
  exit 0
fi

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
pin_version=
if [ -f "$PIN_FILE" ]; then
  pin_version=$(nix_eval --raw --impure --expr "(builtins.fromJSON (builtins.readFile \"$DOTFILES_DIR/$PIN_FILE\")).version")
fi
major=${nixpkgs_version%%.*}

# 次の switch で入る Node(nix/home.nix の nodejsRuntime と同じ判定)
if [ "$node_mode" = auto ] && [ -n "$pin_version" ] && ! version_at_least "$nixpkgs_version" "$pin_version"; then
  next="公式バイナリ $pin_version"
  effective=$pin_version
else
  next="nixpkgs 版 $nixpkgs_version"
  effective=$nixpkgs_version
fi

# index.json は新しい順に並んでいる。同じメジャーで security が true の最初のものを取る
target=
if curl -fsSL --max-time 20 "$DIST_URL/index.json" -o "$tmp/index.json"; then
  target=$(nix_eval --raw --impure --expr "
    let
      releases = builtins.fromJSON (builtins.readFile \"$tmp/index.json\");
      hits = builtins.filter
        (r: r.security && builtins.match \"v$major\\\\..*\" r.version != null)
        releases;
    in if hits == [ ] then \"\" else builtins.substring 1 (-1) (builtins.head hits).version
  ")
fi
if [ -n "$target" ] && ! valid_version "$target"; then
  echo "nodejs-security: 想定外のバージョン表記です: $target" >&2
  exit 1
fi

if [ "$mode" = status ]; then
  current="見つかりません"
  if node_path=$(command -v node 2>/dev/null); then
    real=$(readlink -f "$node_path" 2>/dev/null || printf '%s' "$node_path")
    case "$real" in
      /nix/store/*-nodejs-bin-*) kind="公式バイナリ" ;;
      /nix/store/*) kind="nixpkgs 版" ;;
      *) kind="Nix 以外($real)" ;;
    esac
    current="$kind $(node --version 2>/dev/null | sed 's/^v//')"
  fi
  echo "今使われている Node: $current"
  echo "次の switch で入る Node: $next"
  [ "$node_mode" = nixpkgs ] && echo "  (DOTFILES_NODEJS=nixpkgs で nixpkgs 版に固定中)"
  echo "nixpkgs の nodejs: $nixpkgs_version"
  echo "$PIN_FILE: ${pin_version:-なし}"
  if [ -z "$target" ]; then
    echo "最新のセキュリティリリース($major.x): 取得できませんでした"
  elif version_at_least "$effective" "$target"; then
    echo "最新のセキュリティリリース($major.x): $target(対応済み)"
  else
    echo "最新のセキュリティリリース($major.x): $target(足りていません。dotfiles-update で取り込めます)"
  fi
  exit 0
fi

if [ -z "$target" ]; then
  echo "nodejs-security: Node.js $major.x のセキュリティリリースを取得できませんでした。" >&2
  exit 1
fi

echo "nixpkgs の nodejs: $nixpkgs_version"
echo "$PIN_FILE: ${pin_version:-なし}"
echo "最新のセキュリティリリース($major.x): $target"

if version_at_least "$effective" "$target"; then
  echo "nodejs-security: 対応済みです。"
  exit 0
fi

if [ "$mode" = check ]; then
  echo "nodejs-security: nixpkgs の nodejs が $target に追いついていません。" >&2
  # 判定できなかった場合(ネットワーク不調等)の非0と区別するため、遅れは専用の値で返す
  exit 10
fi

# 署名の検証に使う gpgv。macOS などで入っていなければ、flake.lock の nixpkgs の gnupg を使う
if command -v gpgv >/dev/null 2>&1; then
  gpgv=(gpgv)
else
  gpgv=(nix --extra-experimental-features 'nix-command flakes' shell --inputs-from ./nix nixpkgs#gnupg -c gpgv)
fi

curl -fsSL "$KEYRING_URL" -o "$tmp/pubring.kbx"
curl -fsSL "$DIST_URL/v$target/SHASUMS256.txt.asc" -o "$tmp/SHASUMS256.txt.asc"
# SHASUMS256.txt.asc はクリア署名なので、検証を通った本文だけを使う
if ! "${gpgv[@]}" --keyring "$tmp/pubring.kbx" --output "$tmp/verified-sums.txt" "$tmp/SHASUMS256.txt.asc"; then
  echo "nodejs-security: SHASUMS256.txt の署名を検証できませんでした(何も書き込みません)。" >&2
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

# 書きかけのファイルを残さないよう、一時ファイルに書いてから置き換える
cat >"$tmp/pin.json" <<EOF
{
  "version": "$target",
  "hashes": {
    "x86_64-linux": "$x86_64_linux",
    "aarch64-linux": "$aarch64_linux",
    "aarch64-darwin": "$aarch64_darwin"
  }
}
EOF
mv "$tmp/pin.json" "$PIN_FILE"

echo "nodejs-security: $PIN_FILE に公式バイナリ $target を書きました(次の home-manager switch で入ります)。"
