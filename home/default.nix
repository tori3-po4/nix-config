{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  installPackagesWithNix = config.local.installPackagesWithNix;
in
{
  imports = [
    ./emacs.nix
    ./vscode.nix
    ./zsh.nix
    ./bash.nix
    ./starship.nix
    ./git.nix
    ./nh.nix
    ./dotfiles.nix
  ];

  options.local.installPackagesWithNix = lib.mkOption {
    type = lib.types.bool;
    default = pkgs.stdenv.hostPlatform.isDarwin;
    description = ''
      Whether Home Manager should install the common package list and optional
      Nix integrations.  On Linux the default is false; host software is installed
      by scripts/install-linux-software.sh.  Emacs, Linux GPU
      integration, shell modules and user Flatpak apps are managed separately
      and are not disabled by this option.
    '';
  };

  config.home.stateVersion = "24.11";

  config.home.sessionPath = [
    "$HOME/.local/bin"
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    "$HOME/.local/share/npm-global/bin"
  ];

  # Spotlight/F4 が Nix store への symlink をアプリとして索引化しないため、
  # macOS では .app バンドルを ~/Applications に実体コピーする。
  config.targets.darwin.linkApps.enable = false;
  config.targets.darwin.copyApps.enable = pkgs.stdenv.hostPlatform.isDarwin;

  config.home.packages = lib.mkIf installPackagesWithNix (
    with pkgs;
    [
      # ===== Nix utilties =====
      nh

      # ===== 基本CLI =====
      ripgrep
      fd
      fzf
      jq
      bat
      eza
      coreutils

      # ===== Git周辺 =====
      git
      git-filter-repo
      gh

      # ===== エディタ/シェル支援 =====
      neovim
      vscode
      tmux
      direnv

      # ===== AI agent =====
      inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default # pi コマンド

      # ===== ドキュメント =====
      pandoc

      # ===== 言語処理系 =====
      nodejs_26
      typescript # tsc コマンド
      pnpm
      uv
      pixi
      sbcl # SLIME から使う Common Lisp 実装

      # ===== ビルドツール =====
      automake
      cmake
      meson
      ninja
      pkgconf
      gnumake
      gcc # 競プロ <bits/stdc++.h>、クロスコンパイル
      lld # 高速リンカ
      lldb # デバッガ
      llvm # opt, llc, llvm-objdump 等
      qemu

      # ===== 画像/動画/PDF =====
      ffmpeg
      imagemagick
      libwebp
      poppler

      # ===== ネットワーク/暗号 =====
      yt-dlp
      gnupg

      # ===== Neovim external 管理 (その他の dotfile は Home Manager) =====
      age

      # ===== 専門ツール =====
      tree-sitter
      sqlite
      flyctl
      (aspellWithDicts (dicts: [ dicts.en ]))

      # ===== LaTeX周辺 =====
      texliveFull # MacTeX-no-gui 相当(全部入り)
      ghostscript
      tex-fmt

      # ===== パスワードマネージャー =====
      bitwarden-cli

      # ===== LSP servers (Nvim/Emacs共通) =====
      lua-language-server
      nil
      pyright
      rust-analyzer
      typescript-language-server
      astro-language-server
      tailwindcss-language-server
      texlab
      clang-tools # clangd, clang-format
      marksman
      dockerfile-language-server
      yaml-language-server
      bash-language-server
      vscode-langservers-extracted # html, css, json, eslint LSPs
      nixd

      # ===== Formatters / Linters =====
      stylua
      nixfmt
      ruff
      rustfmt
      prettier
      shellcheck
      shfmt
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      prismlauncher
      moonlight-qt

      # ===== コンテナ =====
      docker-client
      docker-compose
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      # ===== coding agent =====
      codex
    ]
  );
}
