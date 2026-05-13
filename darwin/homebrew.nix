{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # homebrew.nix にない brew/cask は自動アンインストール
    };

    taps = [
      "randomplum/gtkwave"
    ];

    # gtkwave GUI は randomplum tap でのみ macOS 対応されているため brew 残し
    brews = [
      "randomplum/gtkwave/gtkwave"
    ];

    casks = [
      "blender"
      "discord"
      "docker-desktop"
      "font-hackgen-nerd"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "jetbrains-toolbox"
      "logi-options+"
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
