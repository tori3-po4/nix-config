{ pkgs, ... }:
let
  # Evil と同様に、編集は Vim、ファイルやウィンドウ操作は Emacs のキーを使う。
  # C-x の実際の割り当てと M-SPC のヘルプを同じ定義から生成する。
  binding = key: name: command: { inherit key name command; };
  controlXBindings = [
    (binding "ctrl+f" "ファイルを開く" (
      if pkgs.stdenv.hostPlatform.isDarwin then
        "workbench.action.files.openFileFolder"
      else
        "workbench.action.files.openFile"
    ))
    (binding "ctrl+s" "保存" "workbench.action.files.save")
    (binding "ctrl+w" "名前を付けて保存" "workbench.action.files.saveAs")
    (binding "s" "すべて保存" "workbench.action.files.saveAll")
    (binding "b" "バッファを切り替え" "workbench.action.showAllEditors")
    (binding "k" "バッファを閉じる" "workbench.action.closeActiveEditor")
    (binding "0" "現在のウィンドウを閉じる" "workbench.action.closeGroup")
    (binding "1" "ウィンドウを一つにまとめる" "workbench.action.joinAllGroups")
    (binding "2" "上下に分割" "workbench.action.splitEditorDown")
    (binding "3" "左右に分割" "workbench.action.splitEditorRight")
    (binding "o" "次のウィンドウへ" "workbench.action.focusNextGroup")
    (binding "left" "前のバッファへ" "workbench.action.previousEditor")
    (binding "right" "次のバッファへ" "workbench.action.nextEditor")
    (binding "g" "Git の変更を表示" "workbench.view.scm")
  ];
  # 統合ターミナル・検索欄・Quick Pick には編集用のキーを適用しない。
  workbenchWhen = "!terminalFocus && !quickInputVisible && (!inputFocus || editorTextFocus)";
  toMenuBinding = entry: entry // { type = "command"; };
in
{
  programs.vscode = {
    enable = true;
    package = null;
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = (builtins.fromJSON (builtins.readFile ./vscode-settings.json)) // {
        "whichkey.delay" = 400;
        "whichkey.bindings" = [
          {
            key = "ctrl+x";
            name = "C-x: ファイル / バッファ / ウィンドウ";
            type = "bindings";
            bindings = map toMenuBinding controlXBindings;
          }
          (toMenuBinding (binding "alt+x" "M-x: コマンドを実行" "workbench.action.showCommands"))
        ];
      };

      keybindings =
        map (entry: {
          key = "ctrl+x ${entry.key}";
          inherit (entry) command;
          when = workbenchWhen;
        }) controlXBindings
        ++ [
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
            key = "alt+space";
            command = "whichkey.show";
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
        ]
        # Quick Pick は修飾キーや矢印を文字として受け取れないため転送する。
        ++
          map
            (key: {
              inherit key;
              command = "whichkey.triggerKey";
              args = key;
              when = "whichkeyVisible";
            })
            [
              "ctrl+x"
              "ctrl+f"
              "ctrl+s"
              "ctrl+w"
              "alt+x"
              "left"
              "right"
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
          vspacecode.whichkey
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
