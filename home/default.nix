{ lib, pkgs, ... }:
{
  imports = [
    ./emacs.nix
    ./vscode.nix
    ./zsh.nix
    ./bash.nix
    ./starship.nix
    ./firefox.nix
    ./fzf.nix
    ./git.nix
    ./nh.nix
    ./dotfiles.nix
  ];

  home.stateVersion = "24.11";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Spotlight/F4 が Nix store への symlink をアプリとして索引化しないため、
  # macOS では .app バンドルを ~/Applications に実体コピーする。
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = pkgs.stdenv.hostPlatform.isDarwin;

  home.packages =
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
      # Keep Nix terminal tools while preferring Ghostty's own terminfo.
      (lib.lowPrio ncurses)

      # ===== Git周辺 =====
      git
      git-filter-repo
      gh

      # ===== エディタ/シェル支援 =====
      neovim
      vscode
      tmux
      direnv

      # ===== ドキュメント =====
      pandoc

      # ===== 言語処理系 =====
      nodejs_26
      typescript # tsc コマンド
      pnpm
      uv
      pixi
      sbcl # SLIME から使う Common Lisp 実装
      elan # Leanのバージョン管理。lean/lakeはプロジェクトのlean-toolchainに従う。

      # ===== ビルドツール =====
      automake
      cmake
      meson
      pkgconf
      gnumake
      gcc # 競プロ <bits/stdc++.h>、クロスコンパイル
      lld # 高速リンカ
      lldb # デバッガ
      llvm # opt, llc, llvm-objdump 等


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
      # Linux の GUI 本体は linux/flatpak.nix で管理する (VS Code・Emacs は例外)。
      # Ghostty は macOS のみで使用する。
      ghostty-bin
      lmstudio
      prismlauncher
      moonlight-qt

      llvmPackages.openmp # Apple clang で -fopenmp を使うためのランタイム
 
      # ===== コンテナ =====
      docker-client
      docker-compose
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      # ===== coding agent =====
      codex
    ]
  ;
}
