# nodejs.org 公式のビルド済みバイナリを包んだもの。nixpkgs の nodejs が Node.js の
# セキュリティリリースに追いつくまでのあいだだけ使う(切り替えは nix/home.nix、
# 判断根拠は docs/decisions/nodejs-security-releases.md)。
# バージョンとハッシュは nix/nodejs-bin.local.json に置き、scripts/nodejs-security.sh update が
# 署名を検証したうえで書き換える(git 管理外。マシンごとに持つ)。
{ lib, stdenv, fetchurl, pin }:
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

  dontConfigure = true;
  dontBuild = true;
  # 配布元でビルド済みのバイナリなので、fixup で ELF を書き換えない(strip と RUNPATH の
  # 切り詰めも patchelf と同じく ELF を作り直す)。
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R bin include lib share $out/
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Linux 版は一般的な FHS 環境向けにリンクされているため、Nix の libc / libstdc++ を向かせる。
    # autoPatchelfHook は使わない: patchelf 0.19.2 では interpreter を書き換えたあとに RUNPATH を
    # 書き換えると node が起動時に segfault する(RUNPATH が先なら動く。実測)。順番を固定するため
    # 自前で2回に分けて呼ぶ。壊れたら scripts/test-home-manager.sh の 12b が検知する。
    patchelf --set-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" $out/bin/node
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/node
  '' + ''
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
