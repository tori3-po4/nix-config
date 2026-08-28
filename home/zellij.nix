{ ... }:
{
  programs.zellij = {
    enable = true;

    # Emacs/Evil receives every normally bound key during ordinary use.  F12 is
    # unbound in both stock Emacs and this Evil setup, so reserve it solely for
    # entering/leaving Zellij's command modes.
    settings.default_mode = "locked";
    extraConfig = ''
      keybinds {
          locked clear-defaults=true {
              bind "F12" { SwitchToMode "Normal"; }
          }
          shared_except "locked" {
              bind "F12" { SwitchToMode "Locked"; }
          }
      }
    '';
  };
}
