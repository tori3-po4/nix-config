{ lib, pkgs, ... }:

let
  # Pin the actual GNU release archive, not a moving branch or release alias.
  # nixpkgs supplies the Linux PGTK build recipe and dependencies.
  emacs31Source = pkgs.fetchurl {
    url = "mirror://gnu/emacs/emacs-31.1.tar.xz";
    hash = "sha256-HaV5DZWAyBkytb9wBjMRRGjaezQS1p+qdn2uv5dPRYY=";
  };

  # macOS uses Homebrew Emacs Plus.  Build GNU Emacs here only on Linux, with
  # the PGTK GUI; it continues to work in a terminal with `emacs -nw`.
  # Keep native-comp available, but do not eagerly native-compile every bundled
  # Elisp file.  Third-party packages are managed by Emacs' built-in package.el.
  emacsPgtk =
    let
      package =
        (pkgs.emacs31-pgtk.override {
          withNativeCompilation = true;
          withTreeSitter = true;
          # The pinned source is a release tarball rather than a Git checkout.
          srcRepo = false;
        }).overrideAttrs
          (old: {
            version = "31.1";
            src = emacs31Source;
            env = builtins.removeAttrs (old.env or { }) [
              "NATIVE_FULL_AOT"
            ];
          });
    in
    assert lib.assertMsg (
      package.version == "31.1"
    ) "The configured Emacs package must remain exactly at version 31.1";
    assert lib.assertMsg (builtins.elem "--with-pgtk" (
      package.configureFlags or [ ]
    )) "Linux Emacs must be built with the PGTK GUI backend";
    package;
in
{
  # Elisp packages use GNU/NonGNU ELPA; init.el pins Evil to NonGNU-devel.
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;
  xdg.configFile."emacs/early-init.el".source = ./emacs/early-init.el;
  
  # Emacs は ~/.emacs.d が存在すると XDG の ~/.config/emacs よりこちらを
  # 優先する。auto-save 等がディレクトリを作っても設定が外れないよう、
  # legacy 側にも同じ init.el を配置する。
  home.file.".emacs.d/init.el".source = ./emacs/init.el;
  home.file.".emacs.d/early-init.el".source = ./emacs/early-init.el;

  # macOSの本体はnix-darwin管理のHomebrew Emacs Plusに任せる。Linuxでは
  # GNU公式Emacs 31.1をPGTK付きでビルドし、Native Compilation、Tree-sitter、
  # TUI child frameを残しつつフルAOTだけを無効化する。
  programs.emacs = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    enable = true;
    package = emacsPgtk;
  };
}
