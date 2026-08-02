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
      "Sikarugir-App/sikarugir"
      # "randomplum/gtkwave"
    ];

    # gtkwave GUI は randomplum tap でのみ macOS 対応されているため brew 残し
    brews = [
      # "randomplum/gtkwave/gtkwave"
    ];

    casks = [
      "anki"
      "blender"
      "discord"
      "font-hackgen-nerd"
      "google-chrome"
      "logi-options+"
      "minecraft"
      "obsidian"
      "pearcleaner"
      "skim"
      {
        name = "Sikarugir-App/sikarugir/sikarugir";
        trusted = true; # 非公式 tap のうち、この Cask だけ activation 中に信頼する
      }
      "slack"
      "tailscale-app"
      "zotero"
      "wireshark-app"
      "latexit"
      "llama-app"
      "codex"
      "chatgpt"
      "bitwarden"
      "docker-desktop"
      "claude-code@latest"
      "raspberry-pi-imager"
      "balenaetcher"
    ];

  };
}
