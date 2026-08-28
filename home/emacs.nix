{ pkgs, ... }:

let
  # Keep native-comp available, but do not eagerly native-compile every bundled
  # Elisp file.  init.el compiles the GNU/NonGNU packages which are actually
  # installed, so this substantially shortens each Emacs master rebuild.
  emacsTui =
    (pkgs.emacs-git-nox.override {
      withNativeCompilation = true;
      withTreeSitter = true;
    }).overrideAttrs
      (old: {
        env = builtins.removeAttrs (old.env or { }) [
          "NATIVE_FULL_AOT"
          "NIX_CFLAGS_COMPILE"
        ];
      });
in
{
  # package.el のパッケージは init.el 自身が GNU/NonGNU ELPA から管理する。
  # Evil だけは Corfu 互換修正のため NonGNU-devel に固定する。
  xdg.configFile."emacs/early-init.el".source = ./emacs/early-init.el;
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;

  # Emacs は ~/.emacs.d が存在すると XDG の ~/.config/emacs よりこちらを
  # 優先する。auto-save 等がディレクトリを作っても設定が外れないよう、
  # legacy 側にも同じ init.el を配置する。
  home.file.".emacs.d/early-init.el".source = ./emacs/early-init.el;
  home.file.".emacs.d/init.el".source = ./emacs/init.el;

  # macOS/Linux とも Emacs 32 master の no-X 版を使う。Native
  # Compilation と Tree-sitter は残し、フル AOT だけを無効化する。
  programs.emacs = {
    enable = true;
    package = emacsTui;
  };
}
