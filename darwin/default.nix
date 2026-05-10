{ pkgs, username, ... }:
{
  imports = [ ./homebrew.nix ./defaults.nix ];

  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  environment.systemPackages = [];
}
