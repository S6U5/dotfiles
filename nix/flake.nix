{
  description = "Nix + home-manager によるパッケージ管理(一本化)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # mdgrid のソース(nixpkgs に無いため、home.nix でここからビルドする。docs/decisions/mdgrid.md 参照)。
    # flake の入力にしておくと、取得したコミットと中身のハッシュが flake.lock に固定され、
    # 更新は他の入力と同じく Dependabot(.github/dependabot.yml の nix)が PR にする。
    mdgrid = {
      url = "github:S6U5/mdgrid";
      flake = false;
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
          extraSpecialArgs = { mdgridSrc = mdgrid; };
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
