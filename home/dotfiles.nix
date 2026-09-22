{ lib, pkgs, ... }:
{
  # Alacritty 本体・設定・テーマは macOS のみ導入する。
  programs.alacritty = {
    enable = true;
    theme = "github_dark_high_contrast";
    settings = builtins.fromTOML (builtins.readFile ./dotfiles/alacritty.toml);
  };
  home.file.".tmux.conf".source = ./dotfiles/tmux.conf;
  home.file.".latexmkrc".source = ./dotfiles/latexmkrc;
}
