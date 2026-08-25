{ pkgs, ... }:
{
  imports = [
    ./vscode.nix
    ./zed.nix
    ./zsh.nix
    ./bash.nix
    ./starship.nix
    ./firefox.nix
    ./fzf.nix
    ./zoxide.nix
    ./espanso.nix
    ./git.nix
    ./nh.nix
  ];

  home.stateVersion = "24.11";

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Spotlight/F4 が Nix store への symlink をアプリとして索引化しないため、
  # macOS では .app バンドルを ~/Applications に実体コピーする。
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = pkgs.stdenv.hostPlatform.isDarwin;

  home.packages = with pkgs; [
    # ===== Nix utilties =====
    nh

    # ===== 基本CLI =====
    ripgrep
    fd
    fzf
    jq
    bat
    eza
    zoxide
    coreutils

    # ===== Git周辺 =====
    git
    git-filter-repo
    gh

    # ===== エディタ/シェル支援 =====
    neovim
    vscode
    jetbrains.pycharm
    jetbrains.clion
    jetbrains.idea
    tmux
    direnv
    stow
    zellij

    # ===== ターミナルエミュレーター ====
    (if stdenv.hostPlatform.isDarwin then ghostty-bin else ghostty)

    # ===== ローカルLLM =====
    llama-cpp
    lmstudio

    # ===== ゲーム / リモートプレイ ====
    prismlauncher
    moonlight-qt

    # ===== ドキュメント =====
    pandoc

    # ===== 言語処理系 =====
    deno
    nodejs_22
    uv
    pixi

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
    llvmPackages.openmp # Apple clang で -fopenmp を使うためのランタイム
    jdk
    gradle # Java/Kotlin ビルドツール(同梱 JDK ではなく上記 jdk を使う)

    # ===== 画像/動画/PDF =====
    ffmpeg
    imagemagick
    libwebp
    poppler

    # ===== ネットワーク/暗号 =====
    yt-dlp
    gnupg

    # ===== dotfile管理 =====
    chezmoi
    age

    # ===== 専門ツール =====
    tree-sitter
    sqlite
    flyctl

    # ===== コンテナ =====
    docker-client
    docker-compose

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
  ];
}
