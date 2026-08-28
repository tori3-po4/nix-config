{ lib, pkgs, ... }:

let
  # This repository builds Emacs locally and does not share its store output.
  # Optimise the C runtime for the CPU which performs and runs the build.
  cpuFlags =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "-O2 -mcpu=native"
    else if pkgs.stdenv.hostPlatform.isx86_64 then
      "-O2 -march=native -mtune=native"
    else
      "-O2";

  emacsTui =
    (pkgs.emacs-git-nox.override {
      withNativeCompilation = true;
      withTreeSitter = true;
    }).overrideAttrs
      (old: {
        env = (old.env or { }) // {
          NIX_CFLAGS_COMPILE = lib.concatStringsSep " " (
            lib.filter (flags: flags != "") [
              (old.env.NIX_CFLAGS_COMPILE or "")
              cpuFlags
            ]
          );
        };
      });
in
{
  # package.el のパッケージは init.el 自身が GNU/NonGNU ELPA から管理する。
  xdg.configFile."emacs/early-init.el".source = ./emacs/early-init.el;
  xdg.configFile."emacs/init.el".source = ./emacs/init.el;

  # Emacs は ~/.emacs.d が存在すると XDG の ~/.config/emacs よりこちらを
  # 優先する。auto-save 等がディレクトリを作っても設定が外れないよう、
  # legacy 側にも同じ init.el を配置する。
  home.file.".emacs.d/early-init.el".source = ./emacs/early-init.el;
  home.file.".emacs.d/init.el".source = ./emacs/init.el;

  # macOS/Linux とも Emacs 32 master の no-X 版を使う。Nixpkgs の
  # NATIVE_FULL_AOT によるフル AOT と上記の CPU 固有最適化を適用する。
  programs.emacs = {
    enable = true;
    package = emacsTui;
  };
}
