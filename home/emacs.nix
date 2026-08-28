{ lib, pkgs, ... }:
{
  # package.el のパッケージは init.el 自身が GNU/NonGNU ELPA から管理する。
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;

  # Emacs は ~/.emacs.d が存在すると XDG の ~/.config/emacs よりこちらを
  # 優先する。auto-save 等がディレクトリを作っても設定が外れないよう、
  # legacy 側にも同じ init.el を配置する。
  home.file.".emacs.d/init.el".source = ./emacs/init.el;

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
