{ username, ... }:
{
  imports = [
    ./homebrew.nix
    ./defaults.nix
    ./jetbrains-wrapper-fix.nix
  ];

  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
