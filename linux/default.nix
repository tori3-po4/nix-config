{ config, lib, ... }:
let
  bitwardenSshAuthSock =
    "${config.home.homeDirectory}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
  bitwardenSshAgentInit = ''
    export SSH_AUTH_SOCK=${lib.escapeShellArg bitwardenSshAuthSock}
  '';
in
{
  imports = [
    ./flatpak.nix
  ];

  # Flatpak版BitwardenのSSHエージェントを利用する。
  home.sessionVariables.SSH_AUTH_SOCK = bitwardenSshAuthSock;

  # デスクトップセッションが別のSSHエージェントを設定した場合も、
  # 対話シェルではBitwardenを使う。sessionVariablesの再読み込みに依存しない。
  programs.bash.initExtra = lib.mkAfter bitwardenSshAgentInit;
  programs.zsh.initContent = lib.mkAfter bitwardenSshAgentInit;
}
