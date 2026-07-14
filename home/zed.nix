{ ... }:
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

  latexmkCommonArgs = [
    "-verbose"
    "-file-line-error"
    "-synctex=1"
    "-interaction=nonstopmode"
    "-aux-directory=.aux"
    "-output-directory=.out"
    "$ZED_FILE"
  ];
in
{
  programs.zed-editor = {
    enable = true;
    # 本体は他の GUI アプリと同様に home/default.nix の home.packages で管理する。
    package = null;

    # VS Code と同様、設定ファイルは Home Manager だけで管理する。
    mutableUserSettings = false;
    mutableUserKeymaps = false;
    mutableUserTasks = false;
    mutableUserDebug = false;

    extensions = zedExtensions;
    userSettings = builtins.fromJSON (builtins.readFile ./zed-settings.json);

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
        ]
        ++ latexmkCommonArgs;
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
      {
        label = "LaTeX: lualatex";
        command = "latexmk";
        args = [ "-lualatex" ] ++ latexmkCommonArgs;
        cwd = "$ZED_DIRNAME";
        save = "current";
      }
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
