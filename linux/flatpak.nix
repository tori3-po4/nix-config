{
  config,
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  homeDirectory = config.home.homeDirectory;
  xdgConfigHome = config.xdg.configHome;
  firefoxConfigPath = ".mozilla/firefox";
in
{
  # Home Manager 26.05以降のXDGパス変更に影響されず、Flatpak版と
  # ネイティブ版Firefoxが共通で認識する従来の標準パスを使う。
  programs.firefox.configPath = firefoxConfigPath;

  # nix-flatpak の Home Manager module と組み合わせ、ユーザ単位で管理する。
  # アプリ固有の設定内容は home/ に残し、ここでは本体・更新・sandbox の
  # Linux 固有設定だけを宣言する。
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "com.bitwarden.desktop"
      "com.google.Chrome"
      "dev.zed.Zed"
      "net.ankiweb.Anki"
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

    overrides = {
      # programs.firefox が標準のLinuxプロファイルへ生成する設定をFlatpak版から使う。
      # Home Manager管理ファイルのsymlink先を読むため、Nix storeは読み取り専用にする。
      "org.mozilla.firefox".Context.filesystems = [
        "${homeDirectory}/${firefoxConfigPath}:rw"
        "/nix/store:ro"
      ];

      # programs.zed-editor は $XDG_CONFIG_HOME/zed を管理するため、Flatpak内の
      # XDG_CONFIG_HOMEも同じ場所へ揃える。mutableUserSettingsで更新する
      # settings.jsonは書き込み可能、その他のstore symlinkは読み取り専用で参照する。
      "dev.zed.Zed" = {
        Context.filesystems = [
          "${xdgConfigHome}/zed:rw"
          "/nix/store:ro"
        ];
        Environment.XDG_CONFIG_HOME = xdgConfigHome;
      };
    };
  };
}
