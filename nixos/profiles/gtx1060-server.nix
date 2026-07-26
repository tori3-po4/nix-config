{
  lib,
  pkgs,
  ...
}:
{
  # GTX 1060 は Pascal 世代。Open GPU Kernel Modules の対象外なので、
  # Maxwell～Volta 向けに維持されている proprietary 580 系を使う。
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    branch = "legacy_580";
    open = false;
    modesetting.enable = true;
    nvidiaPersistenced = true;
    nvidiaSettings = lib.mkDefault false;
  };

  # Docker 25 以降の CDI を使って NVIDIA GPU をコンテナへ公開する。
  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  # Podman に切り替える場合は上の Docker を false にし、以下を有効にする。
  # NVIDIA Container Toolkit の CDI 構成は Podman でも共通して利用できる。
  #
  # virtualisation.podman = {
  #   enable = true;
  #   dockerCompat = true;
  #   defaultNetwork.settings.dns_enabled = true;
  # };

  # 認証情報は構成へ埋め込まず、初回起動後に `sudo tailscale up` で登録する。
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    wireguard-tools
  ];

  # WireGuard は接続先ごとに以下を設定する。秘密鍵そのものは world-readable
  # な Nix store へ入れず、privateKeyFile で参照する。
  #
  # networking.wg-quick.interfaces.wg0 = {
  #   address = [ "10.10.0.2/24" ];
  #   listenPort = 51820;
  #   privateKeyFile = "/var/lib/wireguard/wg0.key";
  #   peers = [
  #     {
  #       publicKey = "<peer-public-key>";
  #       allowedIPs = [ "10.10.0.0/24" ];
  #       endpoint = "<peer-host>:51820";
  #       persistentKeepalive = 25;
  #     }
  #   ];
  # };
  # networking.firewall.allowedUDPPorts = [ 51820 ];
}
