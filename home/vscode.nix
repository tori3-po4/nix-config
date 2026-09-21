{ pkgs, ... }:
let
  # 統合ターミナル・検索欄・Quick Pick には編集用のキーを適用しない。
  workbenchWhen = "!terminalFocus && !quickInputVisible && (!inputFocus || editorTextFocus)";
in
{
  programs.vscode = {
    enable = true;
    package = null;
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = builtins.fromJSON (builtins.readFile ./vscode-settings.json);

      # Evil と同様に、編集は Vim、ファイルやウィンドウ操作は Emacs のキーを使う。
      keybindings = [
        {
          key = "ctrl+x ctrl+f";
          command =
            if pkgs.stdenv.hostPlatform.isDarwin then
              "workbench.action.files.openFileFolder"
            else
              "workbench.action.files.openFile";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x ctrl+s";
          command = "workbench.action.files.save";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x ctrl+w";
          command = "workbench.action.files.saveAs";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x s";
          command = "workbench.action.files.saveAll";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x b";
          command = "workbench.action.showAllEditors";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x k";
          command = "workbench.action.closeActiveEditor";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x 0";
          command = "workbench.action.closeGroup";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x 1";
          command = "workbench.action.joinAllGroups";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x 2";
          command = "workbench.action.splitEditorDown";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x 3";
          command = "workbench.action.splitEditorRight";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x o";
          command = "workbench.action.focusNextGroup";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x left";
          command = "workbench.action.previousEditor";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x right";
          command = "workbench.action.nextEditor";
          when = workbenchWhen;
        }
        {
          key = "ctrl+x g";
          command = "workbench.view.scm";
          when = workbenchWhen;
        }
        # evil-want-C-i-jump = nil と揃え、Tab は補完・インデントに使う。
        # vim.handleKeys だけでは拡張の Tab 割り当てを解除できない。
        {
          key = "tab";
          command = "-extension.vim_tab";
        }
        {
          key = "alt+x";
          command = "workbench.action.showCommands";
          when = workbenchWhen;
        }
        {
          key = "ctrl+g";
          command = "vim.remap";
          args.after = [ "<Esc>" ];
          when = "editorTextFocus && vim.active && !suggestWidgetVisible && !findWidgetVisible";
        }
        {
          key = "ctrl+g";
          command = "hideSuggestWidget";
          when = "suggestWidgetVisible && textInputFocus";
        }
        {
          key = "ctrl+g";
          command = "closeFindWidget";
          when = "editorFocus && findWidgetVisible";
        }
        {
          key = "ctrl+g";
          command = "workbench.action.closeQuickOpen";
          when = "quickInputVisible";
        }
        {
          key = "ctrl+b";
          command = "cursorLeft";
          when = "editorTextFocus && vim.active && vim.mode == 'Insert'";
        }
        {
          key = "ctrl+f";
          command = "cursorRight";
          when = "editorTextFocus && vim.active && vim.mode == 'Insert'";
        }
        # 既存の実機設定を引き継ぐ。端末には Shift+Enter を ESC+CR として渡す。
        {
          key = "shift+enter";
          command = "workbench.action.terminal.sendSequence";
          args.text = builtins.fromJSON ''"\u001b\r"'';
          when = "terminalFocus";
        }
      ];

      # Zed と同じスニペット定義を共有する。
      languageSnippets.cpp = builtins.fromJSON (builtins.readFile ./cpp-snippets.json);

      extensions =
        (with pkgs.vscode-marketplace; [
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
          ms-vscode.cpptools-extension-pack
          ms-vscode.cpptools-themes
          ms-vscode.remote-explorer
          rust-lang.rust-analyzer
          vscjava.vscode-java-pack
          redhat.java
          astro-build.astro-vscode
          bradlc.vscode-tailwindcss
          vscodevim.vim
          jnoortheen.nix-ide
        ])
        ++ [
          pkgs.vscode-marketplace-release.dbaeumer.vscode-eslint
          # cpptools 本体は nix-vscode-extensions 側で darwin から削除されているため、
          # nixpkgs 同梱版 (allowUnfree) を使う
          pkgs.vscode-extensions.ms-vscode.cpptools
        ];
    };
  };
}
