# nodejs.org 公式のビルド済みバイナリを包んだもの。nixpkgs の nodejs が Node.js の
# セキュリティリリースに追いつくまでのあいだだけ使う(切り替えは nix/home.nix、
# 判断根拠は docs/decisions/nodejs-security-releases.md)。
# バージョンとハッシュは nix/nodejs-bin.json に置き、scripts/nodejs-security.sh update が
# 署名を検証したうえで書き換える。
{ lib, stdenv, fetchurl, autoPatchelfHook, pin }:
let
  # nodejs.org の配布ファイル名との対応(scripts/nodejs-security.sh と揃える)
  platforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  system = stdenv.hostPlatform.system;
  platform = platforms.${system} or (throw "nodejs-bin: 未対応のシステムです: ${system}");
in
stdenv.mkDerivation {
  pname = "nodejs-bin";
  inherit (pin) version;

  src = fetchurl {
    url = "https://nodejs.org/dist/v${pin.version}/node-v${pin.version}-${platform}.tar.xz";
    hash = pin.hashes.${system};
  };

  # Linux 版は一般的な FHS 環境向けにリンクされているため、Nix の libc / libstdc++ を向かせる
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R bin include lib share $out/
    # 同梱の npm / npx / corepack の `#!/usr/bin/env node` を、このパッケージの node に向ける
    export HOST_PATH="$out/bin:$HOST_PATH"
    runHook postInstall
  '';

  meta = {
    description = "Node.js (official prebuilt binary from nodejs.org)";
    homepage = "https://nodejs.org";
    license = lib.licenses.mit;
    platforms = builtins.attrNames platforms;
    mainProgram = "node";
  };
}
