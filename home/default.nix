{ pkgs, ... }:
{
  imports = [ ./vscode.nix ];

  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # ===== 基本CLI =====
    ripgrep
    fd
    fzf
    jq
    #bat
    #eza
    coreutils

    # ===== Git周辺 =====
    git
    git-filter-repo
    lazygit
    gh

    # ===== エディタ/シェル支援 =====
    neovim
    tmux
    helix
    #zoxide
    #starship
    direnv
    stow

    # ===== ターミナルエミュレーター ====
    (if stdenv.isDarwin then ghostty-bin else ghostty)

    # ===== AIコーディング支援 =====
    claude-code

    # ===== ブラウザ =====
    firefox

    # ===== ドキュメント =====
    pandoc

    # ===== 言語処理系 =====
    deno
    nodejs_22
    uv
    opam

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
    iverilog
    llama-cpp
    arduino-cli
    sqlite
    flyctl

    # ===== LaTeX周辺 =====
    texlive.combined.scheme-full # MacTeX-no-gui 相当(全部入り)
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
