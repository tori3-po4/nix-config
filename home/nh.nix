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
      extraArgs = "--keep-since 30d --keep-one";
    };
  };
}
