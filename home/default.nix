{ pkgs, username, ... }:
{
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
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
    lazygit
    gh

    # ===== エディタ/シェル支援 =====
    neovim
    tmux
    zoxide
    starship
    direnv
    stow

    # ===== ドキュメント =====
    pandoc

    # ===== 言語処理系 =====
    deno
    nodejs_22
    uv
    opam
    R

    # ===== ビルドツール =====
    automake
    cmake
    meson
    pkgconf
    gnumake

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

    # ===== LaTeX周辺 =====
    tex-fmt
  ];
}
