{ ... }:
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
      # opam (存在すれば読み込み)
      [[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || \
        source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
    '';
  };
}
