{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    # 将来の既定値変更後も ~/.zshrc などをホーム直下に配置する。
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
      styles = {
        path = "fg=magenta";
        path_pathseparator = "fg=magenta,bold";
        path_prefix = "fg=magenta";
        path_prefix_pathseparator = "fg=magenta,bold";
      };
    };

    history = {
      append = true;
      share = true;
    };

    initContent = ''
      setopt correct
      setopt auto_menu
      setopt print_eight_bit

      # uv 補完
      if command -v uv > /dev/null 2>&1; then
        eval "$(uv generate-shell-completion zsh)"
        eval "$(uvx --generate-shell-completion zsh)"
      fi

      # eat補完
      if [ -n "$EAT_SHELL_INTEGRATION_DIR" ]; then
         source "$EAT_SHELL_INTEGRATION_DIR/zsh"
      fi


      '';
  };
}
