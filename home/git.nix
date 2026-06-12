{ ... }:
{
  # git 本体(パッケージ)は home/default.nix の home.packages で管理(他ツールと同様)。
  # このファイルは設定だけを持ち、パッケージ導入はしない(programs.git は使わない)。
  #
  # 目的: Nix の git が同梱する system gitconfig
  #   (/nix/store/<hash>-git-<ver>/etc/gitconfig) が強制する
  #   credential.helper = osxkeychain を打ち消す。
  #
  # 背景: GitHub へは SSH 接続なので osxkeychain 連携は不要。にもかかわらず Nix の git を
  # 更新するたびに store パス(= コード署名)が変わり、macOS キーチェーンの ACL が一致せず
  # 「キーチェーンの使用を許可しますか」ダイアログが毎回出ていた。
  #
  # 仕組み: ~/.config/git/config(XDG) に空の helper を書く。git の設定読み込み順は
  #   system(/nix/store/.../etc/gitconfig) → XDG(~/.config/git/config) → ~/.gitconfig
  # なので、system で入った helper を XDG の空値でリセットでき、後に読まれる
  # ~/.gitconfig(chezmoi 管理・credential を触らない)では無効のまま残る。
  # user.name / email / init.defaultBranch などは引き続き chezmoi の ~/.gitconfig が真実源。
  xdg.configFile."git/config".text = ''
    [credential]
      helper =
  '';
}
