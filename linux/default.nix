{ config, ... }:
{
  imports = [
    ./flatpak.nix
  ];

  # Flatpak版BitwardenのSSHエージェントを利用する。
  home.sessionVariables.SSH_AUTH_SOCK =
    "${config.home.homeDirectory}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
}
