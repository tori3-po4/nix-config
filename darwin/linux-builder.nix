{
  username,
  linuxSystem,
  emulatedSystems,
  lib,
  ...
}:
{
  # Linux derivation を Nix daemon 経由で builder VM に送れるようにする。
  # trusted-users は root 相当の権限を持つため、ログインユーザだけに限定する。
  nix.settings.trusted-users = [ username ];

  # nix-darwin が launchd service、SSH 鍵、buildMachines をまとめて管理する。
  # VM 自体は Mac と同じ architecture で起動し、Apple Silicon 上の
  # x86_64-linux は VM 内の binfmt/QEMU でエミュレーションする。
  nix.linux-builder = {
    enable = true;
    ephemeral = false;
    systems = [ linuxSystem ] ++ emulatedSystems;
    config = lib.optionalAttrs (emulatedSystems != [ ]) {
      boot.binfmt.emulatedSystems = emulatedSystems;
    };
  };

  # カスタム config を含む builder の初回ビルドには、先に flake の
  # darwinConfigurations.bootstrap で native builder を起動しておく。
}
