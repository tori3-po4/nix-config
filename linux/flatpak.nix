{
  config,
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  options.local.manageFlatpakWithHomeManager = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether Home Manager/nix-flatpak should manage user Flatpak apps.  The
      default is true: the shell installer only installs the Flatpak runtime and
      desktop portal packages, while this module manages user apps and updates.
    '';
  };

  # nix-flatpak の Home Manager module と組み合わせ、ユーザ単位で管理する。
  # ここでは本体と更新だけを宣言し、Firefox のプロファイル・設定・拡張機能は
  # Firefox 自身で管理する。
  config.services.flatpak = lib.mkIf config.local.manageFlatpakWithHomeManager {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "ai.lmstudio.lm-studio"
      "com.bitwarden.desktop"
      "com.google.Chrome"
      "net.ankiweb.Anki"
      "org.kiwix.desktop"
      "org.mozilla.firefox"
      "org.zotero.Zotero"
    ]
    ++ lib.optionals isX86_64 [
      # 現在の Flathub では x86_64 のみ提供されるアプリ。
      "com.discordapp.Discord"
      "com.slack.Slack"
      "org.blender.Blender"
    ];

    # Homebrew の cleanup = "uninstall" と同じく、ユーザ用Flatpakをこの一覧へ収束させる。
    # システム単位で導入したFlatpakには影響しない。
    uninstallUnmanaged = true;

    # home-manager switch のたびにネットワーク更新が走らないようにし、
    # アプリ更新は宣言した週次timerへ分離する。
    update = {
      onActivation = false;
      auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };
}
