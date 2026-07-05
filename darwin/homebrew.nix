{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # homebrew.nix にない brew/cask は自動アンインストール
    };

    # 自己更新型 cask (discord, slack 等) も darwin-rebuild で upgrade させる
    greedyCasks = true;

    taps = [
      # "randomplum/gtkwave"
    ];

    # gtkwave GUI は randomplum tap でのみ macOS 対応されているため brew 残し
    brews = [
      # "randomplum/gtkwave/gtkwave"
    ];

    casks = [
      "blender"
      "discord"
      "font-hackgen-nerd"
      "google-chrome"
      "logi-options+"
      "minecraft"
      "obsidian"
      "pearcleaner"
      "raspberry-pi-imager"
      "skim"
      "slack"
      "tailscale-app"
      "zotero"
      "wireshark-app"
      "latexit"
      "codex-app"
      "bitwarden"
      "docker-desktop"
      "claude-code@latest"
    ];

  };
}
