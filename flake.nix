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

    # espanso が LLVM/clang 21 系に上がった nixpkgs-unstable でリンクエラーになる
    # (aarch64-darwin, exit code 133)。上流で修正されるまで、ビルドが通っていた
    # リビジョンにピン留めして espanso だけここから取る。修正後はこの input と
    # espansoPinOverlay を削除すること。
    nixpkgs-espanso.url = "github:NixOS/nixpkgs/3d46470bb3030020f7e1361f33514854f5bfa86d";

    # llama.cpp 本体は GitHub から取得し、ビルド定義と依存関係は現在の
    # nixpkgs を使う。上流の Nix 定義は削除済みの Darwin SDK 互換属性を
    # 参照しているため、flake としては評価しない。
    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
      flake = false;
    };
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

      # macOS と同じ CPU アーキテクチャの Linux を native build の対象にする。
      # Docker/VM image は Linux の derivation なので、Darwin の pkgs から
      # cross build せず nix-darwin の Linux builder へ委譲する。
      linuxSystemFor =
        system:
        if system == "aarch64-darwin" then
          "aarch64-linux"
        else if system == "x86_64-darwin" then
          "x86_64-linux"
        else
          throw "Unsupported Darwin system for the Linux builder: ${system}";

      # Darwin 対応済みの nixpkgs のビルド定義を使い、ソースだけ GitHub 版へ
      # 差し替える。server 用 Web UI は API 用途では不要なのでビルドしない。
      llamaCppGitHubOverlay = final: prev: {
        llama-cpp = prev.llama-cpp.overrideAttrs (old: {
          version = builtins.substring 0 8 inputs.llama-cpp.lastModifiedDate;
          src = inputs.llama-cpp.outPath;

          nativeBuildInputs = final.lib.subtractLists [
            final.nodejs_latest
            final.npmHooks.npmConfigHook
          ] (old.nativeBuildInputs or [ ]);

          npmDeps = null;
          npmDepsHash = null;
          npmRoot = null;

          preConfigure = ''
            prependToVar cmakeFlags "-DLLAMA_BUILD_COMMIT:STRING=${inputs.llama-cpp.shortRev}"
          '';

          cmakeFlags = (old.cmakeFlags or [ ]) ++ [
            (final.lib.cmakeBool "LLAMA_BUILD_UI" false)
            (final.lib.cmakeBool "LLAMA_USE_PREBUILT_UI" false)
          ];
        });
      };

      # espanso を旧 nixpkgs にピン留め (inputs の nixpkgs-espanso コメント参照)
      espansoPinOverlay = final: prev: {
        espanso = inputs.nixpkgs-espanso.legacyPackages.${prev.stdenv.hostPlatform.system}.espanso;
      };

      # 共通 nixpkgs 設定 (overlay + unfree)
      sharedNixpkgsModule = {
        nixpkgs.overlays = [
          nix-vscode-extensions.overlays.default
          llamaCppGitHubOverlay
          espansoPinOverlay
        ];
        nixpkgs.config.allowUnfree = true;
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
            linuxSystem = linuxSystemFor system;
          };
          modules = [
            ./darwin
            sharedNixpkgsModule
            home-manager.darwinModules.home-manager
            (homeManagerSharedModule { inherit username; })
          ];
        };

      # qcow2 の中身になる NixOS。image の生成処理とは分けておくことで、
      # images/vm.nix を通常の NixOS module として編集・評価できる。
      mkImageNixos =
        system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./images/vm.nix ];
        };

      imageNixos = builtins.listToAttrs (
        map (system: {
          name = system;
          value = mkImageNixos system;
        }) linuxSystems
      );

    in
    {
      darwinConfigurations = {
        ${user.hostname} = mkDarwin { inherit (user) username system; };
        default = mkDarwin { inherit (user) username system; };
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
      #       (homeManagerSharedModule {
      #         username = "<user>";
      #         platformModules = linuxHomeModules;
      #       })
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
      #     modules = [ ./home ] ++ linuxHomeModules;
      #   };
      # ---------------------------------------------------------------------

      nixosConfigurations = {
        image-aarch64 = imageNixos.aarch64-linux;
        image-x86_64 = imageNixos.x86_64-linux;
      };
      homeConfigurations = { };

      # Image は必ず Linux package として公開する。macOS からビルドするときも
      # `packages.<arch>-linux` を明示することで Mach-O の混入を防ぐ。
      packages = builtins.listToAttrs (
        map (
          system:
          let
            pkgs = import nixpkgs { inherit system; };
            nixos = imageNixos.${system};
          in
          {
            name = system;
            value = {
              docker-image = pkgs.callPackage ./images/docker.nix { };
              vm-raw = nixos.config.system.build.image;

              # systemd-repart で作った raw image を変換するだけなので、
              # Linux builder 内で nested KVM を利用できない Mac でも動く。
              qcow2 = pkgs.runCommand "nix-vm-${system}-qcow2" { nativeBuildInputs = [ pkgs.qemu-utils ]; } ''
                mkdir -p "$out"
                qemu-img convert \
                  -f raw \
                  -O qcow2 \
                  ${nixos.config.system.build.image}/${nixos.config.image.filePath} \
                  "$out/nix-vm-${system}.qcow2"
              '';
            };
          }
        ) linuxSystems
      );
    };
}
