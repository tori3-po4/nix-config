{ pkgs, ... }:
{
  imports = [
    ./vscode.nix
    ./zsh.nix
    ./bash.nix
    ./starship.nix
    ./firefox.nix
    ./fzf.nix
    ./zoxide.nix
    ./git.nix
    ./hermes.nix
  ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
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
    lazygit
    gh

    # ===== エディタ/シェル支援 =====
    neovim
    helix
    vscode
    jetbrains.pycharm
    jetbrains.clion
    jetbrains.idea
    tmux
    direnv
    stow
    zellij

    # ===== ターミナルエミュレーター ====
    (if stdenv.isDarwin then ghostty-bin else ghostty)

    # ===== AIコーディング支援 =====
    claude-code
    codex
    # Hermes Agent 本体と ~/.hermes/config.yaml は home/hermes.nix で管理

    # ===== ブラウザ =====
    firefox

    # ===== ドキュメント =====
    pandoc

    # ===== 言語処理系 =====
    deno
    nodejs_22
    #uv

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
    llama-cpp
    arduino-cli
    sqlite
    flyctl

    # ===== コンテナ =====
    # podman: macOS では `podman machine init && podman machine start` で VM を用意
    podman
    podman-compose
    # docker: Hermes Agent の terminal backend は docker 前提(podman は未対応)。
    # macOS にネイティブ dockerd は無いので colima が lima VM 内で daemon を提供し、
    # docker-client(CLI)からその socket を叩く。初回のみ `colima start --vm-type vz`。
    colima
    docker-client
    docker-compose

    # ===== LaTeX周辺 =====
    texlive.combined.scheme-full # MacTeX-no-gui 相当(全部入り)
    ghostscript
    tex-fmt

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
