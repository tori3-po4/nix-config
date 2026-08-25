{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = null;
    mutableExtensionsDir = true;

    profiles.default = {
      userSettings = builtins.fromJSON (builtins.readFile ./vscode-settings.json);

      # Zed と同じスニペット定義を共有する。
      languageSnippets.cpp = builtins.fromJSON (builtins.readFile ./cpp-snippets.json);

      extensions =
        (with pkgs.vscode-marketplace; [
          github.github-vscode-theme
          james-yu.latex-workshop
          jnoortheen.nix-ide
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
          ms-vscode.cpptools-extension-pack
          ms-vscode.cpptools-themes
          ms-vscode.remote-explorer
          rust-lang.rust-analyzer
          vscjava.vscode-java-pack
          redhat.java
        ])
        ++ [
          # cpptools 本体は nix-vscode-extensions 側で darwin から削除されているため、
          # nixpkgs 同梱版 (allowUnfree) を使う
          pkgs.vscode-extensions.ms-vscode.cpptools
        ];
    };
  };
}
