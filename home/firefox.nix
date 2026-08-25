{ ... }:
{
  # Firefox 本体は Homebrew Cask 側で管理しているため、ここでは
  # プロファイル定義 (profiles.ini / user.js) のみを生成する。package = null にすると
  # home-manager は .app を再インストールせず、設定だけ反映する。
  programs.firefox = {
    enable = true;
    package = null;

    # 新規プロファイルとして home-manager に管理させる:
    #   ~/Library/Application Support/Firefox/Profiles/default/user.js
    # path はデフォルトで attribute 名 (= "default") を使うため明示不要。
    # 旧プロファイル (0trwkxau.default) を引き継ぎたい場合は事前にブックマーク
    # 等を export して新プロファイルに import すること。
    profiles.default = {
      isDefault = true;
      # 単一の Profiles/default だけを使う。Store ID は既存プロファイルと
      # profiles.ini の対応を安定させるため、現在の値を維持する。
      storeId = "14355ba7";

      # 値は user.js に user_pref(...) として書き込まれ、毎回起動時に prefs.js を上書きする。
      # 設定変更したくなったら about:config で値を変えてもここの値で戻されるので注意。
      settings = {
        # ===== プロファイル =====
        # この Mac は単一ユーザー・単一プロファイルで運用するため、Firefox の
        # 新しい切り替え可能プロファイル機能を無効化する。
        "browser.profiles.enabled" = false;
        "browser.profiles.created" = false;

        # ===== ロケール / 地域 =====
        "intl.locale.requested" = "ja,en-US";
        "browser.search.region" = "JP";
        "browser.translations.mostRecentTargetLanguages" = "en,ja";

        # ===== UI / テーマ =====
        "extensions.activeThemeID" = "firefox-compact-light@mozilla.org";
        "browser.theme.toolbar-theme" = 1;
        "browser.theme.content-theme" = 1;
        "ui.systemUsesDarkTheme" = 0;
        "layout.css.prefers-color-scheme.content-override" = 1;
        "browser.toolbars.bookmarks.visibility" = "always";
        "layout.css.devPixelsPerPx" = "-1.0";

        # ===== サイドバー =====
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = false;
        "sidebar.main.tools" = "aichat,syncedtabs,history,bookmarks";

        # ===== AI チャット (Claude) =====
        "browser.ml.chat.provider" = "https://claude.ai/new";

        # ===== 新規タブ =====
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.topSitesRows" = 2;

        # ===== プライバシー / テレメトリ =====
        # データアップロードの大元スイッチ
        "datareporting.healthreport.uploadEnabled" = false;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        # ローカル記録自体も止めて CPU / IO を削る (より積極的なオプトアウト)
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        # Normandy = Mozilla の A/B 試験。これも常時バックグラウンドで動くので止める
        "app.normandy.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        # 「おすすめ拡張」探索ジョブ
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;

        # ===== PDF =====
        "pdfjs.enableAltText" = false;

        # ===== パフォーマンス: メモリ最小化方針 =====
        # PyCharm 等の IDE と同時使用前提で、RAM を積極的に切り詰める。
        # 効果の大きい順: コンテンツプロセス数 > BFCache > メディア/メモリキャッシュ。
        # 体感トレードオフ:
        #   - 重いタブが軽いタブの描画を巻き込んで遅くなることがある (processCount 削減)
        #   - 「戻る」が再レンダリングになることが増える (BFCache 削減)
        #   - 長尺動画でバッファ再要求が増える (media.cache_size 削減)

        # --- プロセス数 (1 プロセス概ね 50-150 MB なので最も効く) ---
        # 非 Fission 経路のコンテンツプロセス上限 (デフォルト 8 → 4)
        "dom.ipc.processCount" = 4;
        # Fission (サイト隔離) で立つ WebContent プロセス上限 (デフォルト 4)
        "dom.ipc.processCount.webIsolated" = 4;
        # フォアグラウンドタブを優先 CPU 割当に
        "dom.ipc.processPriorityManager.enabled" = true;

        # --- BFCache (戻る/進む用にレンダ済ページを RAM に保持する仕組み) ---
        # auto (-1) は RAM に比例して 4-8 ページ持つので明示削減
        "browser.sessionhistory.max_total_viewers" = 2;
        # タブあたりの履歴エントリ数 (デフォルト 50)
        "browser.sessionhistory.max_entries" = 10;

        # --- メモリキャッシュ (HTTP レスポンス) ---
        "browser.cache.memory.enable" = true;
        "browser.cache.memory.capacity" = 131072; # KB = 128 MB (旧 512 MB)
        "browser.cache.memory.max_entry_size" = 10240; # KB = 10 MB

        # --- メディアキャッシュ (動画/音声バッファ) ---
        # デフォルト 512 MB → 128 MB
        "media.cache_size" = 131072; # KB = 128 MB

        # --- ディスクキャッシュ (RAM ではないが固定値で運用) ---
        "browser.cache.disk.enable" = true;
        "browser.cache.disk.smart_size.enabled" = false;
        "browser.cache.disk.capacity" = 524288; # KB = 512 MB

        # --- タブのプロアクティブ・アンロード ---
        "browser.tabs.unloadOnLowMemory" = true;
        # 非アクティブから unload 候補になるまでの待ち時間 (ms)。
        # デフォルト相当の 600000 (10 分) を明示固定。
        "browser.tabs.min_inactive_duration_before_unload" = 600000;

        # --- セッション保存 / undo ---
        # 書き込み間隔 15s → 60s (CPU/SSD 負荷 ↓、クラッシュ時の損失 ↑)
        "browser.sessionstore.interval" = 60000;
        # 閉じたタブの undo 上限 (デフォルト 10 → 5)
        "browser.sessionstore.max_tabs_undo" = 5;

        # ===== パフォーマンス: ハードウェアアクセラレーション =====
        # Apple Silicon の GPU / メディアエンジンに decode/描画をオフロード
        # (CPU 仕事 → GPU 仕事に振り替わるだけだが、CPU 競合を IDE と起こしにくい)
        "gfx.canvas.accelerated" = true;
        "media.hardware-video-decoding.force-enabled" = true;

        # ===== ツールバーレイアウト (横タブ構成) =====
        # 添付の attrset / list は home-manager が JSON 文字列に encode して user.js に書き込む。
        "browser.uiCustomization.state" = {
          placements = {
            "widget-overflow-fixed-list" = [ ];
            "unified-extensions-area" = [ ];
            "nav-bar" = [
              "back-button"
              "forward-button"
              "stop-reload-button"
              "sidebar-button"
              "urlbar-container"
              "downloads-button"
              "fxa-toolbar-menu-button"
              "unified-extensions-button"
            ];
            "TabsToolbar" = [
              "firefox-view-button"
              "tabbrowser-tabs"
              "new-tab-button"
              "alltabs-button"
            ];
            "vertical-tabs" = [ ];
            "PersonalToolbar" = [ "personal-bookmarks" ];
          };
          seen = [
            "developer-button"
            "screenshot-button"
          ];
          dirtyAreaCache = [
            "nav-bar"
            "PersonalToolbar"
            "TabsToolbar"
          ];
          currentVersion = 23;
          newElementCount = 2;
        };

        "browser.uiCustomization.horizontalTabstrip" = [
          "firefox-view-button"
          "tabbrowser-tabs"
          "new-tab-button"
          "alltabs-button"
        ];

        "browser.uiCustomization.navBarWhenVerticalTabs" = [
          "back-button"
          "forward-button"
          "stop-reload-button"
          "customizableui-special-spring1"
          "vertical-spacer"
          "sidebar-button"
          "urlbar-container"
          "customizableui-special-spring2"
          "downloads-button"
          "fxa-toolbar-menu-button"
          "unified-extensions-button"
          "firefox-view-button"
          "alltabs-button"
        ];
      };
    };
  };
}
