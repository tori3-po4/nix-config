{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = null;  # 本体は手動インストール (/Applications/Visual Studio Code.app) を使う
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = builtins.fromJSON (builtins.readFile ./vscode-settings.json);

      extensions = with pkgs.vscode-marketplace; [
        anthropic.claude-code
        bradlc.vscode-tailwindcss
        docker.docker
        github.github-vscode-theme
        james-yu.latex-workshop
        ms-azuretools.vscode-containers
        ms-ceintl.vscode-language-pack-ja
        ms-python.debugpy
        ms-python.python
        ms-python.vscode-pylance
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        ms-vscode.cmake-tools
        ms-vscode.cpptools
        ms-vscode.cpptools-extension-pack
        ms-vscode.cpptools-themes
        ms-vscode.remote-explorer
        ocamllabs.ocaml-platform
        pkief.material-icon-theme
        rust-lang.rust-analyzer
      ];
    };
  };
}
