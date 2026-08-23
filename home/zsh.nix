{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
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


      # Ctrl-G: fzf-file-widget をディレクトリ候補で呼び出す(パス挿入のみ)
      # (macOS の Option キー干渉回避もかねる)
      bindkey -r '\ec' 2>/dev/null
      fzf-dir-insert-widget() {
        FZF_CTRL_T_COMMAND="${pkgs.fd}/bin/fd --type d --hidden --follow --exclude .git . $HOME" fzf-file-widget
      }
      zle -N fzf-dir-insert-widget
      bindkey '^G' fzf-dir-insert-widget
    '';
  };
}
