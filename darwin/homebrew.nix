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
      "docker-desktop"
      "emacs-app"
      "font-hackgen-nerd"
      "ghostty"
      "google-japanese-ime"
      "mactex-no-gui"
      "obsidian"
      "pearcleaner"
      "raspberry-pi-imager"
      "rstudio"
      "skim"
      "utm"
    ];

    masApps = {
      # 現状利用なし
    };
  };
}
