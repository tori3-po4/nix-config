{ pkgs, ... }:
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
      if command -v uv > /dev/null 2>&1; then
        eval "$(uv generate-shell-completion bash)"
        eval "$(uvx --generate-shell-completion bash)"
      fi

      # opam (存在すれば読み込み)
      [[ ! -r "$HOME/.opam/opam-init/init.sh" ]] || \
        source "$HOME/.opam/opam-init/init.sh" > /dev/null 2> /dev/null


      # eat統合
      if [ -n "$EAT_SHELL_INTEGRATION_DIR" ]; then
         source "$EAT_SHELL_INTEGRATION_DIR/bash"
      fi

      # Ctrl-G: fzf-file-widget をディレクトリ候補で呼び出す(パス挿入のみ)
      # (macOS の Option キー干渉回避もかねる)
      fzf-dir-insert-widget() {
        FZF_CTRL_T_COMMAND="${pkgs.fd}/bin/fd --type d --hidden --follow --exclude .git . $HOME" fzf-file-widget
      }
      bind -m emacs-standard -x '"\C-g": fzf-dir-insert-widget'
      bind -m vi-command    -x '"\C-g": fzf-dir-insert-widget'
      bind -m vi-insert     -x '"\C-g": fzf-dir-insert-widget'
    '';
  };
}
