{
  description = "Iori's Nix configuration (darwin / nixos / home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-vscode-extensions, nix-homebrew, ... }:
  let
    # 想定対応システム: aarch64-darwin / x86_64-linux / aarch64-linux
    # (実ホストは下の *Configurations で個別に紐づける)

    # 共通 nixpkgs 設定 (overlay + unfree)
    sharedNixpkgsModule = {
      nixpkgs.overlays = [ nix-vscode-extensions.overlays.default ];
      nixpkgs.config.allowUnfree = true;
    };

    # home-manager を system モジュールとして組み込むときの共通設定
    homeManagerSharedModule = { username }: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hmbak";
      home-manager.users.${username} = import ./home;
      home-manager.extraSpecialArgs = { inherit inputs username; };
    };

    # darwinConfigurations のアトリビュート名がホスト名として使われる
    mkDarwin = { username, system }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        modules = [
          ./darwin
          sharedNixpkgsModule
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = username;
              autoMigrate = true; # 既存の手動インストール Homebrew を引き継ぐ
            };
          }
          home-manager.darwinModules.home-manager
          (homeManagerSharedModule { inherit username; })
        ];
      };
  in {
    darwinConfigurations = {
      "your-host" = mkDarwin {
        username = "yourname";
        system   = "aarch64-darwin";
      };
    };

    # ---------------------------------------------------------------------
    # 以下は Linux ホストを追加するときの足場 (現状は空)。
    #
    # NixOS そのものを管理する場合は nixosConfigurations を使う:
    #
    #   nixosConfigurations."<host>" = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux"; # or "aarch64-linux"
    #     specialArgs = { inherit inputs; username = "<user>"; };
    #     modules = [
    #       ./nixos                                    # 別途作成
    #       sharedNixpkgsModule
    #       home-manager.nixosModules.home-manager
    #       (homeManagerSharedModule { username = "<user>"; })
    #     ];
    #   };
    #
    # NixOS 以外の Linux (Ubuntu/Arch 等) に Nix だけ入れて home-manager を
    # 使う場合は standalone home-manager:
    #
    #   homeConfigurations."<user>@<host>" = home-manager.lib.homeManagerConfiguration {
    #     pkgs = import nixpkgs {
    #       system = "x86_64-linux";
    #       config.allowUnfree = true;
    #       overlays = [ nix-vscode-extensions.overlays.default ];
    #     };
    #     extraSpecialArgs = { inherit inputs; username = "<user>"; };
    #     modules = [ ./home ];
    #   };
    # ---------------------------------------------------------------------

    nixosConfigurations = { };
    homeConfigurations  = { };
  };
}
