{
  username,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./homebrew.nix
    ./defaults.nix
    ./symbolic-hotkeys.nix
    ./jetbrains-wrapper-fix.nix
    ./bitwarden.nix
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

  # ログイン設定と .zshrc を読み、普段のシェルの PATH で起動する。
  # exec でシェルを置き換え、launchd が Emacs 本体を管理する。
  launchd.user.agents.emacs = {
    command = "/bin/zsh -lic 'exec /opt/homebrew/bin/emacs --fg-daemon'";
    serviceConfig = {
      Label = "org.nixos.emacs";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      WorkingDirectory = "/Users/${username}";
      StandardOutPath = "/Users/${username}/Library/Logs/emacs-daemon.log";
      StandardErrorPath = "/Users/${username}/Library/Logs/emacs-daemon.error.log";
    };
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
