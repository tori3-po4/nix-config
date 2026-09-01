{ lib, pkgs, ... }:

let
  # Pin the actual GNU release archive, not a moving branch or release alias.
  # nixpkgs supplies only the Darwin/Linux build recipe and dependencies.
  emacs31Source = pkgs.fetchurl {
    url = "mirror://gnu/emacs/emacs-31.1.tar.xz";
    hash = "sha256-HaV5DZWAyBkytb9wBjMRRGjaezQS1p+qdn2uv5dPRYY=";
  };

  # Use the native Cocoa GUI on macOS and the PGTK GUI on Linux.  Both builds
  # continue to work in a terminal with `emacs -nw`.
  #
  # Keep native-comp available, but do not eagerly native-compile every bundled
  # Elisp file.  Third-party packages are managed by Emacs' built-in package.el.
  emacsGui =
    let
      guiPackage = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs31 else pkgs.emacs31-pgtk;
      package =
        (guiPackage.override {
          withNativeCompilation = true;
          withTreeSitter = true;
        }).overrideAttrs
          (old: {
            version = "31.1";
            src = emacs31Source;
            env = builtins.removeAttrs (old.env or { }) [
              "NATIVE_FULL_AOT"
              "NIX_CFLAGS_COMPILE"
            ];
          });
    in
    assert lib.assertMsg (
      package.version == "31.1"
    ) "The configured Emacs package must remain exactly at version 31.1";
    assert lib.assertMsg (builtins.elem (
      if pkgs.stdenv.hostPlatform.isDarwin then "--with-ns" else "--with-pgtk"
    ) (package.configureFlags or [ ])) "Emacs must be built with the platform-native GUI backend";
    package;
in
{
  # Elisp packages are installed from Emacs' default GNU/NonGNU ELPA archives.
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;

  # Emacs は ~/.emacs.d が存在すると XDG の ~/.config/emacs よりこちらを
  # 優先する。auto-save 等がディレクトリを作っても設定が外れないよう、
  # legacy 側にも同じ init.el を配置する。
  home.file.".emacs.d/init.el".source = ./emacs/init.el;

  # 正式版 Emacs 31.1 を、macOS は Cocoa/NS、Linux は PGTK の GUI 付きで
  # ビルドする。Native Compilation、Tree-sitter、TUI child frame は残し、
  # フル AOT だけを無効化する。GNU公式tarballのURL、SHA-256、
  # バージョン検査で31.1以外への暗黙の追従を防ぐ。
  programs.emacs = {
    enable = true;
    package = emacsGui;
  };
}
