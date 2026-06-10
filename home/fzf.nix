{ pkgs, ... }:
{
  programs.fzf = {
    enable = true;
    package = null;
    enableZshIntegration = true;
    enableBashIntegration = true;

    # fd を既定の検索コマンドに(.git やドットファイルも探索)
    defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--info=inline"
    ];

    # CTRL-T(ファイル選択)
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview '${pkgs.bat}/bin/bat --style=numbers --color=always --line-range :200 {}'"
    ];

    # ALT-C(ディレクトリ移動)
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden --follow --exclude .git";
    changeDirWidgetOptions = [
      "--preview '${pkgs.eza}/bin/eza --tree --level=1 --color=always {}'"
    ];

    # CTRL-R(履歴検索)
    historyWidgetOptions = [
      "--sort"
      "--exact"
    ];
  };
}
