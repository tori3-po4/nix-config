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
  xdgDataHome = config.xdg.dataHome;
  firefoxConfigPath = ".mozilla/firefox";
in
{

  # Home Manager 26.05以降のXDGパス変更に影響されず、Flatpak版と
  # ネイティブ版Firefoxが共通で認識する従来の標準パスを使う。
  programs.firefox.configPath = firefoxConfigPath;

  # Fedora実機のinstalls.iniで確認したFlathub版FirefoxのインストールID。
  # Profile0.Defaultだけではインストールごとの起動先を指定できない。
  # 読み取り専用のprofiles.iniへFirefox自身が追記する必要がないよう宣言する。
  home.file."${firefoxConfigPath}/profiles.ini".text = lib.mkAfter ''
    [InstallCF146F38BCAB2D21]
    Default=${config.programs.firefox.profiles.default.path}
    Locked=1
  '';

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
      "ai.lmstudio.lm-studio"
      "com.bitwarden.desktop"
      "com.google.Chrome"
      "com.moonlight_stream.Moonlight"
      "net.ankiweb.Anki"
      "org.mozilla.firefox"
      "org.prismlauncher.PrismLauncher"
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
      # Nix 版で使っていたモデル・設定をそのまま引き継ぐ。
      "ai.lmstudio.lm-studio" = {
        Context.filesystems = [
          "${homeDirectory}/.lmstudio:create"
          "${xdgConfigHome}/LM Studio:create"
        ];
        Environment.XDG_CONFIG_HOME = xdgConfigHome;
      };

      # 接続先・ペアリング情報を従来の Qt 設定ディレクトリで維持する。
      "com.moonlight_stream.Moonlight" = {
        Context.filesystems = [
          "${xdgConfigHome}/Moonlight Game Streaming Project:create"
        ];
        Environment.XDG_CONFIG_HOME = xdgConfigHome;
      };

      # programs.firefox が標準のLinuxプロファイルへ生成する設定をFlatpak版から使う。
      # Home Manager管理ファイルのsymlink先を読むため、Nix storeは読み取り専用にする。
      "org.mozilla.firefox".Context.filesystems = [
        "${homeDirectory}/${firefoxConfigPath}:rw"
        "/nix/store:ro"
      ];

      # インスタンス・ワールド等の可変データはコピーせず元の場所を使う。
      "org.prismlauncher.PrismLauncher" = {
        Context.filesystems = [ "${xdgDataHome}/PrismLauncher:create" ];
        Environment.XDG_DATA_HOME = xdgDataHome;
      };

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
