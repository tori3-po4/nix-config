{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # homebrew.nix にない brew/cask は自動アンインストール
    };

    # 自己更新型 cask (discord, slack, docker-desktop 等) も darwin-rebuild で upgrade させる
    greedyCasks = true;

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
      "google-chrome"
      "jetbrains-toolbox"
      "logi-options+"
      "minecraft"
      "obsidian"
      "pearcleaner"
      "r-app"
      "raspberry-pi-imager"
      "rstudio"
      "skim"
      "slack"
      "tailscale-app"
      "utm"
      "zotero"
      "xquartz"
      "wireshark-app"
    ];

  };
}
