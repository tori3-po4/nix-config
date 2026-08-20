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
      "mole"
    ];

    casks = [
      "anki"
      "blender"
      "discord"
      "font-hackgen-nerd"
      # Mozilla 公式 DMG の本体だけを Cask 管理し、プロファイルは Home Manager で維持する。
      {
        name = "firefox";
        args.language = "ja";
      }
      "google-chrome"
      "logi-options+"
      "minecraft"
      "obsidian"
      "pearcleaner"
      "skim"
      "slack"
      "tailscale-app"
      # 公式 Developer ID 署名を維持し、macOS の TCC 権限を更新後も引き継ぐ。
      "zed"
      "zotero"
      "wireshark-app"
      "latexit"
      "llama-app"
      "codex"
      "chatgpt"
      "bitwarden"
      "docker-desktop"
      "claude-code@latest"
    ];

  };
}
