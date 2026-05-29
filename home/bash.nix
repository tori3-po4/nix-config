{ ... }:
{
  programs.bash = {
    enable = true;

    historyControl = [
      "ignoredups"
      "erasedups"
    ];
    historyFileSize = 10000;
    historySize = 10000;

    shellOptions = [
      "histappend"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
    ];

    initExtra = ''
      # uv 補完
      eval "$(uv generate-shell-completion bash)"
      eval "$(uvx --generate-shell-completion bash)"

      # opam (存在すれば読み込み)
      [[ ! -r "$HOME/.opam/opam-init/init.sh" ]] || \
        source "$HOME/.opam/opam-init/init.sh" > /dev/null 2> /dev/null
    '';
  };
}
