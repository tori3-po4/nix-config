{
  lib,
  pkgs,
  ...
}:
let
  # 内蔵キーボードは LocationID 0xda、外部キーボード (M87US) は
  # 0x1100000。UsagePage / Usage も指定して、内蔵トラックパッド等を除外する。
  internalKeyboardMatcher = builtins.toJSON {
    LocationID = 218; # 0xda
    PrimaryUsagePage = 1;
    PrimaryUsage = 6;
  };

  capsControlMapping = builtins.toJSON {
    UserKeyMapping = [
      {
        HIDKeyboardModifierMappingSrc = 30064771129; # Caps Lock
        HIDKeyboardModifierMappingDst = 30064771296; # Left Control
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771296; # Left Control
        HIDKeyboardModifierMappingDst = 30064771129; # Caps Lock
      }
    ];
  };

  applyInternalKeyboardMapping = pkgs.writeShellScript "apply-internal-keyboard-mapping" ''
    # 以前の全キーボード共通マッピングを消して、外部キーボードを標準に戻す。
    /usr/bin/hidutil property --set '{"UserKeyMapping":[]}'

    # 内蔵キーボードにだけ Caps Lock / 左 Control の入れ替えを適用する。
    /usr/bin/hidutil property \
      --matching ${lib.escapeShellArg internalKeyboardMatcher} \
      --set ${lib.escapeShellArg capsControlMapping}
  '';
in
{
  system.defaults = {
    dock = {
      autohide = false;
      launchanim = true;
      mineffect = "genie";
      minimize-to-application = true;
      mru-spaces = false;
      show-recents = false;
      tilesize = 60;
      wvous-br-corner = 1;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "icnv";
    };

    # ANSI (英語) 配列には「英数」「かな」キーがないため、配列に依存しない
    # 入力ソース切り替えを有効にする。
    hitoolbox.AppleFnUsageType = "Change Input Source";

    NSGlobalDomain = {
      AppleEnableSwipeNavigateWithScrolls = false;
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleShowAllExtensions = true;
      AppleSpacesSwitchOnActivate = true;
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
    };

    universalaccess = {
      reduceTransparency = true;
    };

    trackpad = {
      Clicking = false;
      Dragging = false;
      DragLock = false;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerTapGesture = 0;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
    };

    menuExtraClock = {
      ShowAMPM = true;
      ShowDate = 0;
      ShowDayOfWeek = true;
    };

    WindowManager = {
      GloballyEnabled = false;
      AutoHide = false;
      AppWindowGroupingBehavior = true;
      EnableTiledWindowMargins = false;
      HideDesktop = true;
      StageManagerHideWidgets = false;
      StandardHideWidgets = false;
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleMiniaturizeOnDoubleClick = 0;
        # Caps Lock (内蔵キーボードでは物理左 Control) で日本語入力と
        # ABC を切り替えられるようにする。
        TISRomanSwitchState = 1;
      };

      "com.apple.dock" = {
        wvous-br-modifier = 0;
      };

      "com.apple.universalaccess" = {
        increaseContrast = 1;
      };

      "com.apple.AppleMultitouchTrackpad" = {
        ActuateDetents = 1;
        ForceSuppressed = 0;
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadHandResting = 1;
        TrackpadHorizScroll = 1;
        TrackpadMomentumScroll = 1;
        TrackpadPinch = 1;
        TrackpadRotate = 1;
        TrackpadScroll = 1;
        TrackpadThreeFingerHorizSwipeGesture = 2;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadTwoFingerDoubleTapGesture = 1;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        USBMouseStopsTrackpad = 0;
      };

      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadHandResting = 1;
        TrackpadHorizScroll = 1;
        TrackpadMomentumScroll = 1;
        TrackpadPinch = 1;
        TrackpadRotate = 1;
        TrackpadScroll = 1;
        TrackpadThreeFingerHorizSwipeGesture = 2;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadTwoFingerDoubleTapGesture = 1;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        USBMouseStopsTrackpad = 0;
      };

      "com.apple.screencapture" = {
        style = "window";
        video = 0;
        location = "~/Pictures/Screenshots";
      };
    };
  };

  # hidutil の設定は再起動で消えるため、ログインのたびに再適用する。
  launchd.user.agents.internal-keyboard-mapping = {
    command = "${applyInternalKeyboardMapping}";
    serviceConfig.RunAtLoad = true;
  };

  networking = {
    knownNetworkServices = [
      "Wi-Fi"
      "Thunderbolt Ethernet"
    ];

    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
  };
}
