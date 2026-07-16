{
  ...
}:
{
  programs.sh = {
    enable = true;
    package = null;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 3";
    };
  };
}
