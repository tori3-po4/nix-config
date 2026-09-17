{
  config,
  lib,
  pkgs,
  ...
}:
let
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
  home.packages = [ pkgs.hackgen-nf-font ];

  # デスクトップセッションが別のSSHエージェントを設定した場合も、
  # 対話シェルではBitwardenを使う。sessionVariablesの再読み込みに依存しない。
  programs.bash.initExtra = lib.mkAfter bitwardenSshAgentInit;
  programs.zsh.initContent = lib.mkAfter bitwardenSshAgentInit;

  targets.genericLinux = {
    enable = true;
    gpu = {
      enable = true;
    };
  };

  # cuda用の環境変数を入れる。
  home.sessionPath = [
    "/usr/local/cuda-13.4/bin"
  ];

  home.sessionVariables.CUDA_PATH =
    "/usr/local/cuda-13.4";

  home.sessionVariables.CUDACXX =
    "/usr/local/cuda-13.4/bin/nvcc";

  home.sessionVariables.CUDAHOSTCXX =
    "${pkgs.gcc}/bin/g++";

  home.sessionVariables.NVCC_CCBIN =
    "${pkgs.gcc}/bin/g++";
}
