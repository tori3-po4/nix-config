{
  lib,
  modulesPath,
  ...
}:
let
  serverProfile = ../nixos/profiles/gtx1060-server.nix;
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"
  ];

  # Calamares が生成するインストール先の configuration.nix から、
  # このリポジトリのサーバープロファイルを自動的に import する。
  nixpkgs.overlays = [
    (final: prev: {
      calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./calamares-gtx1060-server.patch ];
        postInstall = (old.postInstall or "") + ''
          cp ${serverProfile} \
            "$out/lib/calamares/modules/nixos/gtx1060-server.nix"
        '';
      });
    })
  ];

  # Calamares から proprietary packages を選べるようにし、NVIDIA
  # specialisation で必要になる userspace driver も評価可能にする。
  nixpkgs.config.allowUnfree = true;

  isoImage = {
    edition = "gtx1060";
    configurationName = lib.mkDefault "Open drivers (Intel / AMD / Nouveau)";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 通常の起動項目は Intel/AMD と Nouveau を使う。GTX 1060 ではこちらの
  # specialisation を選び、Pascal 対応の proprietary 580 系を利用する。
  specialisation.nvidia.configuration = {
    imports = [ serverProfile ];
    isoImage.configurationName = "NVIDIA GTX 1060 (legacy 580)";
    hardware.nvidia.nvidiaSettings = lib.mkForce true;
  };
}
