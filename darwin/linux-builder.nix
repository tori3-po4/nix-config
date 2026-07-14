{ username, linuxSystem, ... }:
{
  # Linux derivation を Nix daemon 経由で builder VM に送れるようにする。
  # trusted-users は root 相当の権限を持つため、ログインユーザだけに限定する。
  nix.settings.trusted-users = [ username ];

  # nix-darwin が launchd service、SSH 鍵、buildMachines をまとめて管理する。
  # builder の store は維持し、再ビルド時に差分だけを転送する。
  nix.linux-builder = {
    enable = true;
    ephemeral = false;
    systems = [ linuxSystem ];
  };

  # 初回から config.virtualisation.* を変更すると、カスタム builder 自体を
  # Linux builder なしでビルドする bootstrap 問題が起こり得る。まず既定の
  # cache 済み image で有効化し、容量不足になった場合だけ適用後に拡張する。
}
