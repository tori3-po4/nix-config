{ config, lib, pkgs, ... }:
{
  # macOS では本体も Nix で導入する。Linux では本体は dnf/apt 側に任せ、
  # Home Manager は設定ファイルだけを配置する。
  programs.alacritty = {
    enable = true;
    package = if config.local.installPackagesWithNix then pkgs.alacritty else null;
    theme = if config.local.installPackagesWithNix then "github_dark_high_contrast" else null;
    settings = builtins.fromTOML (builtins.readFile ./dotfiles/alacritty.toml);
  };
  home.file.".tmux.conf".source = ./dotfiles/tmux.conf;
  home.file.".latexmkrc".source = ./dotfiles/latexmkrc;
}
