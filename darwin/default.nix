{ username, inputs, ... }:
{
  imports = [
    ./homebrew.nix
    ./defaults.nix
    ./symbolic-hotkeys.nix
    ./jetbrains-wrapper-fix.nix
    ./bitwarden.nix
    ./llm.nix
    ./linux-builder.nix
  ];

  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # flake 運用なので旧来のチャネル機構は無効化し、
  # NIX_PATH の <nixpkgs> もこの flake の nixpkgs に揃える。
  nix.channel.enable = false;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # /etc/zshrc の compinit が fpath をフルスキャンして ~1.5s かかる。
  # home-manager 側 (~/.zshrc) で compinit するので無効化する。
  # tmux パネル/新規 zsh 起動の体感速度に直結。
  programs.zsh = {
    enable = true;
    enableCompletion = false;
    promptInit = ""; # starship を使うので prompt suse は不要
  };

  environment.systemPackages = [ ];
}
