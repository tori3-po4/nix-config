{
  config,
  lib,
  ...
}:
{
  programs.nh = lib.mkIf config.local.installPackagesWithNix {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 3";
    };
  };
}
