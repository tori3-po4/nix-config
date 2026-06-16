{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = null;
    mutableExtensionsDir = false;

    profiles.default = {
      userSettings = builtins.fromJSON (builtins.readFile ./vscode-settings.json);

      languageSnippets = {
        cpp = {
          "meguru binary search" = {
            prefix = "binsearch";
            body = [
              "long long ok = \${1:ok};"
              "long long ng = \${2:ng};"
              "while (abs(ok - ng) > 1) {"
              "    long long mid = (ok + ng) / 2;"
              "    if (\${3:check(mid)}) ok = mid;"
              "    else ng = mid;"
              "}"
              "\${0}"
            ];
            description = "めぐる式二分探索";
          };

          "shakutori two pointers" = {
            prefix = "shakutori";
            body = [
              "int r = 0;"
              "for (int l = 0; l < n; l++) {"
              "    while (r < n && \${1:condition}) {"
              "        // add a[r]"
              "        \${2}"
              "        r++;"
              "    }"
              ""
              "    // use interval [l, r)"
              "    \${3}"
              ""
              "    if (r == l) {"
              "        r++;"
              "    } else {"
              "        // remove a[l]"
              "        \${4}"
              "    }"
              "}"
              "\${0}"
            ];
            description = "尺取り法";
          };

          "bit exhaustive search" = {
            prefix = "bitall";
            body = [
              "for (int bit = 0; bit < (1 << n); bit++) {"
              "    for (int i = 0; i < n; i++) {"
              "        if (bit & (1 << i)) {"
              "            \${1:// selected}"
              "        } else {"
              "            \${2:// not selected}"
              "        }"
              "    }"
              ""
              "    \${3:// process subset}"
              "}"
              "\${0}"
            ];
            description = "bit全探索";
          };

          "一般" = {
            prefix = "競技プログラミング（C++）";
            isFileTemplate = true;
            body = [
              "#include <bits/stdc++.h>"
              "using namespace std;"
              "using lint = long long;"
              "#define rep(i, n) for (long long i = 0; i < n; i++)"
              "const long long INF (1LL << 60);"
              "template<typename... T> void input(T&... inp){ (cin >> ... >>inp); }"
              "int main()"
              "{"
              "    \${0}"
              "}"
            ];
          };

          "2 次元配列の宣言" = {
            prefix = "v_2_define";
            body = [
              "vector<vector<\${1:lint}>> \${2:V}(\${3:H}, vector<\${1:lint}>(\${4:W}, \${5:0}));"
            ];
          };

          "1 次元配列入力" = {
            prefix = "v_1_in";
            body = [
              "vector<\${1:lint}> \${2:V}(\${3:N}); rep(i_, \${3:N}) cin >> \${2:V}[i_];"
              ""
            ];
          };

          "1 次元 2 列入力" = {
            prefix = "2_v_1_in";
            body = [
              "vector<lint> \${1:A}(\${3:N}), \${2:B}(\${3}); rep(i_, \${3}) { cin >> \${1}[i_] >> \${2}[i_]; }"
              ""
            ];
          };

          "2 次元配列入力" = {
            prefix = "v_2_in";
            body = [
              "vector<vector<\${1:lint}>> \${2:V}(\${3:H}, vector<\${1:lint}>(\${4:W}, 0)); rep(i_, \${3:H}){ rep(j_, \${4:W}){ cin >> \${2:V}[i_][j_]; }}"
              ""
            ];
          };

          "1 整数値入力" = {
            prefix = "i_1_in";
            body = [
              "lint \${1:N}; cin >> \${1:N};"
              ""
            ];
          };

          "2 整数値入力" = {
            prefix = "i_2_in";
            body = [
              "lint \${1:N}, \${2:M}; cin >> \${1:N} >> \${2:M};"
              ""
            ];
          };

          "昇順 for" = {
            prefix = "rep";
            body = [
              "for(int \${1:i} = \${2:0}; \${1:i} < \${3:N}; \${1:i}++){"
              "    \${0}"
              "}"
            ];
          };

          "降順 for" = {
            prefix = "-rep";
            body = [
              "for(int \${1:i} = \${3:N}; \${1:i} >= \${2:1}; \${1:i}--){"
              "    \${0}"
              "}"
            ];
          };

          "1 整数値標準出力" = {
            prefix = "i_1_out";
            body = [
              "cout << \${1:ans} << '\\n';"
              ""
            ];
          };

          "1 整数値標準エラー出力" = {
            prefix = "i_1_log";
            body = [
              "clog << \${1:ans} << '\\n';"
              ""
            ];
          };

          "1 次元 lint 配列標準出力" = {
            prefix = "v_1_out";
            body = [
              "for(int k_ = 0; k_ < \${1:V}.size(); k_++){ cout << \$1[k_]; if(k_ != \$1.size() - 1){ cout << ' '; }else{ cout << endl; }}"
              ""
            ];
          };

          "1 次元 lint 配列標準エラー出力" = {
            prefix = "v_1_log";
            body = [
              "for(auto k_ : \${1:配列名}){ clog << k_ << ' '; } clog << '\\n';"
              ""
            ];
          };

          "2 次元 lint 配列標準エラー出力" = {
            prefix = "v_2_log";
            body = [
              "for(auto v_ : \${1:配列名}){ for(auto k_ : v_) { clog << k_ << ' '; } clog << '\\n'; }"
              ""
            ];
          };

          "3 整数値標準エラー出力" = {
            prefix = "i_3_log";
            body = [
              "clog << \$1 << ' ' << \$2 << ' ' << \$3 << endl;"
              ""
            ];
          };

          "転置" = {
            prefix = "tenti";
            body = [
              "auto tenti = \${1:v};"
              "for(int i_ = 0; i < \$1.size(); i++){"
              "    for(int j_ = 0; j < \$1.size(); j++){"
              "        tenti[i_][j_] = \${1:v}[j_][i_];"
              "    }"
              "}"
              "\${1:v} = tenti;"
            ];
          };

          "グリッド出力" = {
            prefix = "grid";
            body = [
              "for(int i = H - 1; i >= 0; i--){"
              "    for(int j = 0; j < W; j++){"
              "        clog << G[i][j] << ' ';"
              "    }"
              "    clog << endl;"
              "}"
            ];
          };

          "グリッドの境界判定" = {
            prefix = "boundary";
            body = [
              "if(\${1:n}x == -1 || \${1}x == W || \${1}y == -1 || \${1}y == H) continue;"
              ""
            ];
          };

          "インタラクティブなデバッグ" = {
            prefix = "interactive";
            body = [
              "while {"
              "     lint inp; cin >> inp;"
              "     if(inp == -1) break;"
              "     cout << \${1:V[inp]} << endl;"
              "}\${0}"
            ];
          };
        };
      };

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
          vscodevim.vim
          pdconsec.vscode-print
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
