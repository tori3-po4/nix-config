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

    # Flatpak の宣言管理モジュール自体を安定版へ固定する。
    # Flatpak アプリの実体は Nix store 外に置かれるため、アプリの更新方針は
    # linux/flatpak.nix 側で明示的に管理する。
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
 };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-vscode-extensions,
      ...
    }:
    let
      # ホスト/ユーザ固有情報は private/user.nix に隔離 (.gitignore 対象)
      # gitignore されたファイルは flake のストアコピーに含まれないため、
      # 実ユーザの $HOME を起点にした絶対パスで読み込む。実行時は `--impure` が必要。
      # sudo 経由だと HOME が /var/root に化けるので SUDO_USER から復元する。
      realHome =
        let
          sudoUser = builtins.getEnv "SUDO_USER";
          envHome = builtins.getEnv "HOME";
        in
        if sudoUser != "" then
          (if builtins.pathExists "/Users/${sudoUser}" then "/Users/${sudoUser}" else "/home/${sudoUser}")
        else
          envHome;
      user = import "${realHome}/nix-config/private/user.nix";

      # 想定対応システム: aarch64-darwin / x86_64-linux / aarch64-linux
      # (実ホストは下の *Configurations で個別に紐づける)

      linuxSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      isDarwin = nixpkgs.lib.hasSuffix "-darwin" user.system;
      isSupportedLinux = builtins.elem user.system linuxSystems;

      # 共通 nixpkgs 設定 (overlay + unfree)
      sharedOverlays = [
        nix-vscode-extensions.overlays.default
      ];

      sharedNixpkgsModule = {
        nixpkgs.overlays = sharedOverlays;
        nixpkgs.config.allowUnfree = true;
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = sharedOverlays;
          config.allowUnfree = true;
        };

      # Linuxユーザ環境で ./home に追加するプラットフォーム固有module。
      # nix-flatpak本体のmoduleと、アプリ一覧・overrideを必ず同時に読み込む。
      linuxHomeModules = [
        inputs.nix-flatpak.homeManagerModules.nix-flatpak
        ./linux
      ];

      # home-manager を system モジュールとして組み込むときの共通設定
      homeManagerSharedModule =
        {
          username,
          platformModules ? [ ],
        }:
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hmbak";
          home-manager.users.${username}.imports = [ ./home ] ++ platformModules;
          home-manager.extraSpecialArgs = { inherit inputs username; };
        };

      # darwinConfigurations のアトリビュート名がホスト名として使われる
      mkDarwin =
        { username, system }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit inputs username;
          };
          modules = [
            ./darwin
            sharedNixpkgsModule
            home-manager.darwinModules.home-manager
            (homeManagerSharedModule { inherit username; })
          ];
        };

      # NixOS 以外の Linux で使う standalone Home Manager 構成。
      # 非標準の homeDirectory にも対応できるよう、実行ユーザの
      # HOME をそのまま使う。
      mkLinuxHome =
        {
          username,
          system,
          homeDirectory,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = { inherit inputs username; };
          modules = [
            ./home
          ]
          ++ linuxHomeModules
          ++ [
            {
              home = {
                inherit username homeDirectory;
              };

              # 初回適用後は `home-manager switch` だけで更新できるようにする。
              programs.home-manager.enable = true;
            }
          ];
        };

    in
    assert isDarwin || isSupportedLinux;
    {
      darwinConfigurations = nixpkgs.lib.optionalAttrs isDarwin {
        ${user.hostname} = mkDarwin { inherit (user) username system; };
        default = mkDarwin { inherit (user) username system; };
      };

      # ---------------------------------------------------------------------
      # NixOS ホストを追加するときの足場。
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
      #       (homeManagerSharedModule {
      #         username = "<user>";
      #         platformModules = linuxHomeModules;
      #       })
      #     ];
      #   };
      # ---------------------------------------------------------------------

      # Fedora など NixOS 以外の Linux では、private/user.nix の値から
      # standalone Home Manager 構成を公開する。default は初回導入用、
      # <user>@<host> は Home Manager の標準的な構成名として使える。
      homeConfigurations = nixpkgs.lib.optionalAttrs isSupportedLinux {
        "${user.username}@${user.hostname}" = mkLinuxHome {
          inherit (user) username system;
          homeDirectory = realHome;
        };
        default = mkLinuxHome {
          inherit (user) username system;
          homeDirectory = realHome;
        };
      };

    };
}
