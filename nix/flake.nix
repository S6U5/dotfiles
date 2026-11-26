{
  description = "Nix + home-manager によるパッケージ管理(一本化)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # mdgrid(nixpkgs に無いため、mdgrid 自身の flake のパッケージを入れる。docs/decisions/mdgrid.md 参照)。
    # 既定のブランチではなくリリースのタグを指す(開発中の版が入らず、`--version` がタグと合う)。
    # 取得するコミットと中身のハッシュは flake.lock が固定する。新しいタグは Dependabot
    # (.github/dependabot.yml の nix)が見つけ、ここのタグと flake.lock をまとめて PR にする。
    # nixpkgs はこのリポのものに揃え、2つ目の nixpkgs を取ってこない。
    mdgrid = {
      url = "github:S6U5/mdgrid/v0.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, mdgrid, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      homeConfigurations = forEachSystem (
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./home.nix ];
          extraSpecialArgs = { mdgrid = mdgrid.packages.${system}.default; };
        }
      );

      # home-manager コマンド未導入の環境(CI 等)から、flake.lock に固定された
      # home-manager CLI を実行するための出力(scripts/test-home-manager.sh が使う)。
      # レジストリ経由の `nix run home-manager` は毎回 HEAD を未認証の GitHub API で
      # 解決するため、共有 CI ランナーではレート制限(HTTP 403)で断続的に失敗する。
      packages = forEachSystem (system: {
        home-manager = home-manager.packages.${system}.home-manager;
      });
    };
}
