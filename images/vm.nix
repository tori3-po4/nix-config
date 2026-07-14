{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/image/repart.nix"
  ];

  networking = {
    hostName = "nix-vm";
    useDHCP = lib.mkDefault true;
  };

  # systemd-boot と UKI を EFI System Partition へ直接配置するため、
  # NixOS の通常の boot loader インストール処理は使わない。
  boot.loader.grub.enable = false;

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/root";
    fsType = "ext4";
  };

  # make-disk-image.nix と違い、systemd-repart は build 中に VM/KVM を
  # 起動しない。Apple Silicon の Linux builder でも nested VM 不要。
  image.repart = {
    name = "nix-vm-${pkgs.stdenv.hostPlatform.system}";
    sectorSize = 512;
    partitions = {
      esp = {
        contents =
          let
            efiArch = pkgs.stdenv.hostPlatform.efiArch;
          in
          {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
              "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
            "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
              "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = if pkgs.stdenv.hostPlatform.isx86_64 then "64M" else "96M";
        };
      };

      root = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          Minimize = "guess";
          SizeMinBytes = "2G";
        };
      };
    };
  };

  # ローカル確認用の最小ユーザ。パスワードログインと SSH は有効にせず、
  # VM のコンソールだけ自動ログインにする。
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  services.getty.autologinUser = "nixos";
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = [ pkgs.hello ];

  system.stateVersion = "25.11";
}
