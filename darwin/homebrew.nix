{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall"; # homebrew.nix にない brew/cask は自動アンインストール
    };

    taps = [
      "randomplum/gtkwave"
    ];

    # Nix化が難しいmacOS toolchain系のみbrew残し
    brews = [
      "sqlite"
      "flyctl"
      "randomplum/gtkwave/gtkwave"
    ];

    casks = [
      "blender"
      "claude-code"
      "cmake-app"
      "discord"
      "docker-desktop"
      "font-hackgen-nerd"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "jetbrains-toolbox"
      "logi-options+"
      "mactex-no-gui"
      "minecraft"
      "obsidian"
      "pearcleaner"
      "raspberry-pi-imager"
      "rstudio"
      "skim"
      "slack"
      "tailscale-app"
      "utm"
      "zotero"
    ];

    masApps = {
      # masApps は使用しない (Slack/Tailscale は cask に統一)
    };
  };
}
