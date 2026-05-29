{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      append = true;
      share = true;
    };

    initContent = ''
      setopt correct
      setopt auto_menu
      setopt print_eight_bit

      # uv 補完
      eval "$(uv generate-shell-completion zsh)"
      eval "$(uvx --generate-shell-completion zsh)"

      # opam (存在すれば読み込み)
      [[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || \
        source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
    '';
  };
}
