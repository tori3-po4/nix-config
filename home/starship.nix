{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    settings = {
      add_newline = false;
      format = "$shell$nix_shell$directory\n$git_branch$git_status$character";

      shell = {
        disabled = false;
        bash_indicator = "bash";
        zsh_indicator = "zsh";
        fish_indicator = "fish";
        unknown_indicator = "?";
        style = "bold yellow";
        format = "[$indicator]($style) ";
      };

      nix_shell = {
        impure_msg = "impure";
        pure_msg = "pure";
        unknown_msg = "unknown";
        style = "bold blue";
        format = "[nix:$state]($style) ";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = false;
        style = "bold cyan";
      };

      git_branch = {
        format = "[on $branch]($style) ";
        style = "bold purple";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style)) ";
        style = "bold yellow";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };
}
