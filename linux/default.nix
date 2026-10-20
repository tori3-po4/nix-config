{
  config,
  lib,
  pkgs,
  ...
}:
let
  installPackagesWithNix = config.local.installPackagesWithNix;
  bitwardenSshAuthSock = "${config.home.homeDirectory}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock";
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

  # GUIログイン時に常駐し、Emacs Clientから同じデーモンへ接続する。
  # パッケージは programs.emacs の固定済みEmacsを引き継ぐ。
  services.emacs = {
    enable = true;
    startWithUserSession = "graphical";
    client.enable = true;
  };

  # デスクトップが設定した別のエージェントを継承しないよう明示する。
  systemd.user.services.emacs.Service.Environment = [
    "SSH_AUTH_SOCK=${bitwardenSshAuthSock}"
  ];

  #fontの設定を追加した
  fonts.fontconfig.enable = true;
  home.packages = lib.mkIf installPackagesWithNix [ pkgs.hackgen-nf-font ];

  # デスクトップセッションが別のSSHエージェントを設定した場合も、
  # 対話シェルではBitwardenを使う。sessionVariablesの再読み込みに依存しない。
  programs.bash.initExtra = lib.mkAfter bitwardenSshAgentInit;
  programs.zsh.initContent = lib.mkAfter bitwardenSshAgentInit;

  # Nix 版 Emacs 向けの GPU 連携。
  targets.genericLinux = {
    enable = true;
    gpu = {
      enable = true;

      nvidia = {
        enable = true;
        version = "615.71.09";
        sha256 = "sha256-zc7tIrvrYSSNGm3qvCWWZz46ZQFpjucayNL9wo87cP4=";
      };
    };
  };

  # CUDA 本体・PATH・コンパイラの選択は、今後の専用スクリプトで管理する。
}
