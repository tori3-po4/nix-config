{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";  # 最初は必ず "none"。安定後に "uninstall" → "zap"
    };

    taps = [
      "randomplum/gtkwave"
    ];

    # Nix化が難しいmacOS toolchain系のみbrew残し
    brews = [
      "sqlite"
      "flyctl"
      "gcc"
      "libomp"
      "llvm"
      "randomplum/gtkwave/gtkwave"
    ];

    casks = [
      "blender"
      "claude-code"
      "cmake-app"
      "discord"
      "docker-desktop"
      "emacs-app"
      "font-hackgen-nerd"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "jetbrains-toolbox"
      "logi-options-plus"
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
      "visual-studio-code"
    ];

    masApps = {
      # masApps は使用しない (Slack/Tailscale は cask に統一)
    };
  };
}
