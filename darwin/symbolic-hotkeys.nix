let
  # AppleSymbolicHotKeys の value.parameters:
  # [ 文字コード キーコード 修飾キーフラグ ]
  #
  # 主な修飾キーフラグ:
  #   Shift   = 131072
  #   Control = 262144
  #   Option  = 524288
  #   Command = 1048576
  # 複数の修飾キーは値を加算する。
  standard = enabled: parameters: {
    inherit enabled;
    value = {
      inherit parameters;
      type = "standard";
    };
  };
in
{
  # この辞書全体を宣言し、macOS のショートカット設定を Nix で完全管理する。
  # ID 60/61 は Minecraft の Control + Space と競合するため無効化する。
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
    # キーボードフォーカス
    "7" = standard true [
      65535
      120
      262144
    ]; # メニューバーへ移動: Control+F2
    "8" = standard true [
      65535
      99
      262144
    ]; # Dock へ移動: Control+F3
    "9" = standard true [
      65535
      118
      262144
    ]; # アクティブ/次のウインドウへ移動: Control+F4
    "10" = standard true [
      65535
      96
      262144
    ]; # ウインドウツールバーへ移動: Control+F5
    "11" = standard true [
      65535
      97
      262144
    ]; # フローティングウインドウへ移動: Control+F6
    "12" = standard true [
      65535
      122
      262144
    ]; # キーボードアクセス切り替え: Control+F1
    "13" = standard true [
      65535
      98
      262144
    ]; # Tab のフォーカス移動方法を変更: Control+F7

    # アクセシビリティ
    "15" = standard false [
      56
      28
      1572864
    ]; # ズーム切り替え: Option+Command+8
    "16" = {
      enabled = false;
    }; # キー未割り当て
    "17" = standard false [
      94
      24
      1572864
    ]; # ズームイン: Option+Command+= (ANSI)
    "18" = {
      enabled = false;
    }; # キー未割り当て
    "19" = standard false [
      45
      27
      1572864
    ]; # ズームアウト: Option+Command+-
    "20" = {
      enabled = false;
    }; # キー未割り当て
    "21" = standard false [
      56
      28
      1835008
    ]; # 色反転: Shift+Option+Command+8
    "22" = {
      enabled = false;
    }; # キー未割り当て
    "23" = standard false [
      165
      93
      1572864
    ]; # 画像スムージング: Option+Command+¥ (JIS 固有キー)
    "24" = {
      enabled = false;
    }; # キー未割り当て
    "25" = standard false [
      46
      47
      1835008
    ]; # コントラストを上げる: Shift+Option+Command+.
    "26" = standard false [
      44
      43
      1835008
    ]; # コントラストを下げる: Shift+Option+Command+,

    # ウインドウ・スクリーンショット
    "27" = standard true [
      64
      33
      1048576
    ]; # 次のウインドウへ移動: Command+@ (JIS) / Command+[ (ANSI)
    "28" = standard true [
      51
      20
      1179648
    ]; # 画面をファイルに保存: Shift+Command+3
    "29" = standard true [
      51
      20
      1441792
    ]; # 画面をクリップボードへコピー: Control+Shift+Command+3
    "30" = standard true [
      52
      21
      1179648
    ]; # 選択範囲をファイルに保存: Shift+Command+4
    "31" = standard true [
      52
      21
      1441792
    ]; # 選択範囲をクリップボードへコピー: Control+Shift+Command+4

    # Mission Control
    "32" = standard true [
      65535
      126
      2359296
    ]; # すべてのウインドウ: Control+↑
    "33" = standard true [
      65535
      125
      2359296
    ]; # アプリケーションウインドウ: Control+↓
    "34" = standard true [
      65535
      126
      2490368
    ]; # すべてのウインドウ (スロー): Shift+Control+↑
    "35" = standard true [
      65535
      125
      2490368
    ]; # アプリケーションウインドウ (スロー): Shift+Control+↓
    "36" = standard true [
      65535
      103
      0
    ]; # デスクトップを表示: F11
    "37" = standard true [
      65535
      103
      131072
    ]; # デスクトップを表示 (スロー): Shift+F11

    # Dock・ディスプレイ・VoiceOver
    "51" = standard true [
      64
      33
      1572864
    ]; # Option+Command+@ (JIS) / Option+Command+[ (ANSI)
    "52" = standard true [
      100
      2
      1572864
    ]; # Dock の自動表示切り替え: Option+Command+D
    "53" = standard true [
      65535
      107
      0
    ]; # 輝度を下げる: 輝度−キー (F14)
    "54" = standard true [
      65535
      113
      0
    ]; # 輝度を上げる: 輝度＋キー (F15)
    "55" = standard true [
      65535
      107
      524288
    ]; # 輝度を少し下げる: Option+輝度−キー
    "56" = standard true [
      65535
      113
      524288
    ]; # 輝度を少し上げる: Option+輝度＋キー
    "57" = standard true [
      65535
      100
      262144
    ]; # ステータスメニューへ移動: Control+F8
    "59" = standard true [
      65535
      96
      1048576
    ]; # VoiceOver 切り替え: Command+F5

    # 入力ソース: Minecraft の Control + Space と競合するため無効
    "60" = standard false [
      32
      49
      262144
    ]; # 前の入力ソース: Control+Space
    "61" = standard false [
      32
      49
      786432
    ]; # 次の入力ソース: Control+Option+Space

    # macOS システムショートカット
    "62" = standard true [
      65535
      111
      0
    ]; # F12
    "63" = standard true [
      65535
      111
      131072
    ]; # Shift+F12
    "64" = standard true [
      65535
      49
      1048576
    ]; # Spotlight: Command+Space
    "65" = standard true [
      65535
      49
      1572864
    ]; # Finder 検索: Option+Command+Space
    "70" = standard true [
      100
      2
      1310720
    ]; # 辞書で調べる: Control+Command+D
    "73" = standard true [
      65535
      53
      1048576
    ]; # Command+Escape
    "75" = standard false [
      65535
      100
      0
    ]; # F8
    "76" = standard false [
      65535
      100
      131072
    ]; # Shift+F8

    # Spaces
    "79" = {
      enabled = true;
    }; # 前の操作スペース: Control+← (macOS 既定値)
    "80" = {
      enabled = true;
    }; # 前の操作スペース (スロー): Shift+Control+←
    "81" = {
      enabled = true;
    }; # 次の操作スペース: Control+→ (macOS 既定値)
    "82" = {
      enabled = true;
    }; # 次の操作スペース (スロー): Shift+Control+→

    "98" = standard true [
      47
      44
      1179648
    ]; # ヘルプメニュー: Shift+Command+/

    # デスクトップ 1〜4 へ直接移動
    "118" = standard false [
      65535
      18
      262144
    ]; # デスクトップ1へ移動: Control+1
    "119" = standard false [
      65535
      19
      262144
    ]; # デスクトップ2へ移動: Control+2
    "120" = standard false [
      65535
      20
      262144
    ]; # デスクトップ3へ移動: Control+3
    "121" = standard false [
      65535
      21
      262144
    ]; # デスクトップ4へ移動: Control+4

    "156" = standard true [
      65535
      49
      393216
    ]; # トラックパッド手書き入力: Shift+Control+Space
    "164" = standard false [
      65535
      65535
      0
    ]; # キー未割り当て
    "176" = {
      enabled = false;
      value.type = "standard";
    }; # キー未割り当て
  };
}
