{ ... }:
{
  # 既存の設定内容を保持し、配置のみを Home Manager に移す。
  xdg.configFile."ghostty/config".source = ./dotfiles/ghostty.conf;
  home.file.".tmux.conf".source = ./dotfiles/tmux.conf;
  home.file.".latexmkrc".source = ./dotfiles/latexmkrc;
}
