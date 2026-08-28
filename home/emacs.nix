{ lib, pkgs, ... }:
{
  # package.el のパッケージは init.el 自身が GNU/NonGNU ELPA から管理する。
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;

  # macOS の GUI は Emacs Plus を Homebrew で管理する。Linux は
  # emacs-overlay の master snapshot を PGTK (Wayland 対応) で導入する。
  # emacs-git-pgtk は native-comp、tree-sitter、xwidgets、dynamic modules、
  # SQLite、WebP、mailutils を有効にしてビルドされる。
  programs.emacs = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    package = pkgs.emacs-git-pgtk.override {
      withNativeCompilation = true;
      withTreeSitter = true;
      withXwidgets = true;
    };
  };
}
