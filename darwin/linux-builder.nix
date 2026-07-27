{
  lib,
  username,
  linuxSystem,
  ...
}:
let
  # Apple Silicon では QEMU/binfmt を使い、x86_64-linux derivation も
  # 同じ builder VM で実行できるようにする。Intel Mac では native のため不要。
  emulatedSystems = lib.optional (linuxSystem != "x86_64-linux") "x86_64-linux";
in
{
  # Linux derivation を Nix daemon 経由で builder VM に送れるようにする。
  # trusted-users は root 相当の権限を持つため、ログインユーザだけに限定する。
  nix.settings.trusted-users = [ username ];

  # nix-darwin が launchd service、SSH 鍵、buildMachines をまとめて管理する。
  # builder の store は維持し、再ビルド時に差分だけを転送する。
  nix.linux-builder = {
    enable = true;
    ephemeral = false;
    systems = [ linuxSystem ] ++ emulatedSystems;
    config.boot.binfmt.emulatedSystems = emulatedSystems;
  };

  # 初回から config.virtualisation.* を変更すると、カスタム builder 自体を
  # Linux builder なしでビルドする bootstrap 問題が起こり得る。まず既定の
  # cache 済み image で有効化し、容量不足になった場合だけ適用後に拡張する。
}
