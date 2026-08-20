{ lib, pkgs, ... }:
let
  zedExtensions = [
    "dockerfile"
    "github-theme"
    "html"
    "java"
    "latex"
    "lua"
    "make"
    "nix"
    "toml"
  ];

  baseZedSettings = builtins.fromJSON (builtins.readFile ./zed-settings.json);

  platformZedSettings = lib.optionalAttrs pkgs.stdenv.isDarwin {
    lsp.texlab.settings.texlab = {
      build.forwardSearchAfter = true;
      forwardSearch = {
        executable = "/Applications/Skim.app/Contents/SharedSupport/displayline";
        args = [
          "-r"
          "%l"
          "%p"
          "%f"
        ];
      };
    };
  };

  latexmkCommonArgs = [
    "-verbose"
    "-file-line-error"
    "-synctex=1"
    "-interaction=nonstopmode"
    "-aux-directory=.aux"
    "-output-directory=.out"
    "$ZED_FILE"
  ];

  mkLatexSkimTask =
    { label, latexmkArgs }:
    {
      inherit label;
      command = "/bin/zsh";
      args = [
        "-c"
        ''
          previewDirectory="$1"
          previewStem="$2"
          shift 2
          latexmk "$@" && open -a Skim "$previewDirectory/.out/$previewStem.pdf"
        ''
        "zed-latex-preview"
        "$ZED_DIRNAME"
        "$ZED_STEM"
      ]
      ++ latexmkArgs
      ++ latexmkCommonArgs;
      cwd = "$ZED_DIRNAME";
      save = "current";
    };
in
{
  programs.zed-editor = {
    enable = true;
    # 本体は公式 Developer ID 署名を保持する Homebrew Cask で管理する。
    package = null;

    # Remote Projects の SSH 接続情報を Zed が保存できるよう、設定の変更を許可する。
    mutableUserSettings = true;
    mutableUserKeymaps = false;
    mutableUserTasks = false;
    mutableUserDebug = false;

    extensions = zedExtensions;
    userSettings = lib.recursiveUpdate baseZedSettings platformZedSettings;

    userTasks = [
      {
        label = "C23: Build active file";
        command = "gcc";
        args = [
          "-std=c23"
          "-O2"
          "-Wall"
          "-Wextra"
          "$ZED_FILE"
          "-o"
          "$ZED_DIRNAME/$ZED_STEM"
        ];
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
      {
        label = "C++23: Build active file";
        command = "g++";
        args = [
          "-std=c++23"
          "-O2"
          "-Wall"
          "-Wextra"
          "$ZED_FILE"
          "-o"
          "$ZED_DIRNAME/$ZED_STEM"
        ];
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
      {
        label = "CMake: Configure";
        command = "cmake";
        args = [
          "-S"
          "$ZED_WORKTREE_ROOT"
          "-B"
          "$ZED_WORKTREE_ROOT/build"
          "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
        ];
        cwd = "$ZED_WORKTREE_ROOT";
        save = "all";
      }
      {
        label = "CMake: Build";
        command = "cmake";
        args = [
          "--build"
          "$ZED_WORKTREE_ROOT/build"
          "--parallel"
        ];
        cwd = "$ZED_WORKTREE_ROOT";
        save = "all";
      }
      {
        label = "LaTeX: platex -> dvipdfmx";
        command = "latexmk";
        args = [
          "-latex=platex"
          "-pdfdvi"
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
          "-aux-directory=.aux"
          "-output-directory=.out"
          "$ZED_FILE"
        ];
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
      {
        label = "LaTeX: lualatex";
        command = "latexmk";
        args = [
          "-lualatex"
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
          "-aux-directory=.aux"
          "-output-directory=.out"
          "$ZED_FILE"
        ];
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      (mkLatexSkimTask {
        label = "LaTeX: platex -> dvipdfmx -> Skim";
        latexmkArgs = [
          "-latex=platex"
          "-pdfdvi"
        ];
      })
      (mkLatexSkimTask {
        label = "LaTeX: lualatex -> Skim";
        latexmkArgs = [ "-lualatex" ];
      })
    ];

    userDebug = [
      {
        label = "Python: Active File";
        adapter = "Debugpy";
        request = "launch";
        program = "$ZED_FILE";
        cwd = "$ZED_WORKTREE_ROOT";
      }
      {
        label = "C++23: Build and debug active file";
        adapter = "CodeLLDB";
        request = "launch";
        program = "$ZED_DIRNAME/$ZED_STEM";
        cwd = "$ZED_DIRNAME";
        build = {
          command = "g++";
          args = [
            "-std=c++23"
            "-g"
            "-O0"
            "-Wall"
            "-Wextra"
            "$ZED_FILE"
            "-o"
            "$ZED_DIRNAME/$ZED_STEM"
          ];
          cwd = "$ZED_DIRNAME";
        };
      }
      {
        label = "C23: Build and debug active file";
        adapter = "CodeLLDB";
        request = "launch";
        program = "$ZED_DIRNAME/$ZED_STEM";
        cwd = "$ZED_DIRNAME";
        build = {
          command = "gcc";
          args = [
            "-std=c23"
            "-g"
            "-O0"
            "-Wall"
            "-Wextra"
            "$ZED_FILE"
            "-o"
            "$ZED_DIRNAME/$ZED_STEM"
          ];
          cwd = "$ZED_DIRNAME";
        };
      }
      {
        label = "Java: Launch";
        adapter = "Java";
        request = "launch";
        cwd = "$ZED_WORKTREE_ROOT";
      }
    ];
  };

  # programs.zed-editor に snippets オプションはないため、公式の配置先へ宣言的に置く。
  xdg.configFile."zed/snippets/c++.json".source = ./cpp-snippets.json;
}
