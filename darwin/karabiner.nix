{
  lib,
  pkgs,
  username,
  ...
}:
let
  # Minecraft itself is a Java process, not the Prism Launcher process.
  # These are the bundle identifiers used by the JDKs supplied by Prism,
  # Mojang's launcher, and nixpkgs on macOS.
  minecraftJavaCondition = {
    type = "frontmost_application_if";
    bundle_identifiers = [
      "^com\\.azul\\.zulu\\.java$"
      "^net\\.java\\.openjdk\\.cmd$"
      "^net\\.java\\.openjdk\\.java$"
    ];
  };

  karabinerConfig = (pkgs.formats.json { }).generate "karabiner.json" {
    global = {
      check_for_updates_on_startup = false;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
    };

    profiles = [
      {
        name = "Default profile";
        selected = true;

        complex_modifications.rules = [
          {
            description = "Minecraft: swap Caps Lock and left Control";
            manipulators = [
              {
                type = "basic";
                from = {
                  key_code = "caps_lock";
                  modifiers.optional = [ "any" ];
                };
                to = [ { key_code = "left_control"; } ];
                conditions = [ minecraftJavaCondition ];
              }
              {
                type = "basic";
                from = {
                  key_code = "left_control";
                  modifiers.optional = [ "any" ];
                };
                to = [ { key_code = "caps_lock"; } ];
                conditions = [ minecraftJavaCondition ];
              }
            ];
          }
        ];
      }
    ];
  };

  karabinerConfigDir = "/Users/${username}/.config/karabiner";
  karabinerConfigFile = "${karabinerConfigDir}/karabiner.json";
in
{
  homebrew.casks = [ "karabiner-elements" ];

  # Karabiner does not reliably reload karabiner.json when that file itself is
  # a symlink. Keep a regular, writable file and refresh it on system activation.
  system.activationScripts.karabinerConfig.text = ''
    /usr/bin/install -d -m 0700 \
      -o ${lib.escapeShellArg username} -g staff \
      ${lib.escapeShellArg karabinerConfigDir}

    if [[ ! -f ${lib.escapeShellArg karabinerConfigFile} ]] \
      || ! ${pkgs.diffutils}/bin/cmp -s ${karabinerConfig} ${lib.escapeShellArg karabinerConfigFile}; then
      /usr/bin/install -m 0600 \
        -o ${lib.escapeShellArg username} -g staff \
        ${karabinerConfig} ${lib.escapeShellArg karabinerConfigFile}
    fi
  '';
}
