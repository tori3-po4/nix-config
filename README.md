# nix-config — macOS / Linux 環境の宣言的管理

macOS は nix-darwin + Home Manager、Fedora などの Linux は standalone Home Manager で管理する個人用設定です。パッケージと dotfile はこのリポジトリに集約しています。Neovim は Nix のパッケージをデフォルト設定で使い、chezmoi は削除済みです。SSH 接続設定はローカルで管理し、秘密鍵には Bitwarden SSH agent を使います。

## 目次

1. [全体構成](#1-全体構成)
2. [リポジトリ構成](#2-リポジトリ構成)
3. [日常運用コマンド](#3-日常運用コマンド)
4. [何をどこで管理しているか](#4-何をどこで管理しているか)
5. [移行履歴](#5-移行履歴)
6. [新マシンセットアップ手順](#6-新マシンセットアップ手順)
7. [トラブルシュート](#7-トラブルシュート)
8. [既知の制限](#8-既知の制限)

## 1. 全体構成

| 管理対象 | macOS | Linux |
|---|---|---|
| OS・システム設定 | nix-darwin（defaults、キーボード、DNS、launchd） | OS 側で管理（dnf、systemd 等） |
| CLI・開発ツール・dotfile | Home Manager | Home Manager |
| Neovim / VS Code / Alacritty | Nix | Nix |
| Emacs 本体 | Homebrew Emacs Plus | Nix の Emacs 31.1 PGTK |
| Emacs 設定 / デーモン | Home Manager / launchd | Home Manager / systemd user service |
| Firefox・Chrome・Anki・Zotero・Bitwarden・Kiwix 等 | Homebrew Cask | nix-flatpak（ユーザ単位） |
| Firefox のプロファイル・設定・拡張機能 | Firefox 自身 / Firefox Sync | Firefox 自身 / Firefox Sync |
| LM Studio | Nix | Flatpak |
| Prism Launcher / Moonlight | Nix | この構成では導入しない |
| Codex | Homebrew Cask | Nix |
| SSH agent の接続先 | `~/.bitwarden-ssh-agent.sock` | `~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock` |

設定の読み込み順は `flake.nix` → `darwin/` + `home/`（macOS）、または `home/` + `linux/`（Linux）。Nix の依存は `flake.lock` で固定する。Homebrew / Flatpak のアプリ、Emacs が取得するパッケージ・Tree-sitter 文法、elan のツールチェーンは Nix store 外でも管理されるため、すべてが `flake.lock` だけで固定されるわけではない。

現在の macOS 設定は **Apple Silicon (`aarch64-darwin`)** を前提とする。Linux の構成は `x86_64-linux` / `aarch64-linux` を受け付けるが、GPU・CUDA の設定はホストに合わせて変更する必要がある。NixOS 用の output はまだ定義していない。

## 2. リポジトリ構成

```text
~/nix-config/
├── flake.nix                 # inputs、overlay、OS 別の構成
├── flake.lock                # Nix の依存リビジョン
├── README.md
├── nix-macos-guide.md        # 移行・構築時の参考資料（過去の構成を含む）
├── sunshine-moonlight.md     # Windows → Mac のゲームストリーミング手順
├── private/
│   ├── user.nix.example      # ホスト・ユーザ情報のテンプレート
│   └── user.nix              # 各ホストで作成するローカル設定（Git 管理外）
├── darwin/
│   ├── default.nix           # imports、Emacs デーモン、Nix / zsh 設定
│   ├── homebrew.nix          # Cask、mole、Emacs Plus tap
│   ├── defaults.nix          # macOS 設定、内蔵キーボードのキー交換、DNS
│   ├── symbolic-hotkeys.nix  # macOS ショートカット
│   ├── bitwarden.nix         # シェル / launchd の SSH_AUTH_SOCK
│   └── jetbrains-wrapper-fix.nix # Nix 版 JetBrains 用 overlay
├── linux/
│   ├── default.nix           # Emacs、SSH agent、フォント、GPU / CUDA
│   └── flatpak.nix           # GUI アプリ、更新 timer
└── home/
    ├── default.nix           # 共通パッケージ、imports、macOS の .app コピー
    ├── emacs.nix             # Linux の Emacs 本体と共通設定の配置
    ├── emacs/
    │   ├── early-init.el     # LSP の plist、GC、初期フレーム設定
    │   └── init.el           # Evil、Corfu、lsp-mode、Magit、Eat 等
    ├── vscode.nix           # 拡張、キー操作、C++ スニペット
    ├── vscode-settings.json # VS Code の User 設定
    ├── cpp-snippets.json    # VS Code の C++ スニペット
    ├── zsh.nix / bash.nix   # シェル、uv 補完、Eat 連携
    ├── starship.nix         # 両シェルのプロンプト
    ├── git.nix              # Git 設定の配置と credential helper のリセット
    ├── nh.nix               # nh と週次の世代・store 清掃
    ├── dotfiles.nix         # Alacritty、tmux、latexmk の設定
    └── dotfiles/
        ├── alacritty.toml
        ├── gitconfig
        ├── tmux.conf
        └── latexmkrc
```

`flake.nix` は `private/user.nix` の `username` / `hostname` / `system` を読み、macOS では `darwinConfigurations.<host>` と `darwinConfigurations.default`、Linux では `homeConfigurations."<user>@<host>"` と `homeConfigurations.default` を公開する。共通 overlay は `nix-vscode-extensions` で、unfree パッケージを許可している。

`private/user.nix` は **実ユーザの `~/nix-config/private/user.nix` を絶対パスで import** するため、評価・ビルド・適用には `--impure` が必要。sudo 経由では `SUDO_USER` から実ユーザのホームを復元する。このファイルを `git add -N -f` する必要はない。配置先を変える場合は `flake.nix` の読み込み先も変更する。

## 3. 日常運用コマンド

### Nix側

#### macOS (nix-darwin)

```bash
# 設定変更後の反映 (sudo 必須。--impure は private/user.nix を $HOME 起点で読むため必須)
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# 履歴確認
sudo darwin-rebuild --list-generations

# 直前世代に戻す (壊れた時)
sudo darwin-rebuild --rollback

# 入力(リポジトリ)を最新に更新
cd ~/nix-config
nix flake update
# → 更新後は switch の前に必ずビルドが通るか確認する:
nix build .#darwinConfigurations.default.system --impure --no-link
# 壊れていたら「7. トラブルシュート → nix flake update 後にビルドが壊れた」参照
```

#### macOS のアプリ管理権限

`home/default.nix` は Spotlight から見つけられるよう、Home Manager の `targets.darwin.copyApps` で `.app` を `~/Applications` へコピーする。更新や GC がアプリ管理権限で失敗した場合は、「システム設定 → プライバシーとセキュリティ → アプリ管理」でコマンドを実行しているターミナル／エディタを許可し、そのアプリを再起動する。

#### Linux (standalone Home Manager)

`sudo` は付けず、対象ユーザ自身で実行する。`--impure` は
`private/user.nix` を実行ユーザの `HOME` から読むため必須。

```bash
# 設定変更後の反映
home-manager switch --flake ~/nix-config#default --impure

# switch せずにビルドだけ確認
home-manager build --flake ~/nix-config#default --impure

# 履歴確認
home-manager generations

# 入力を更新し、ビルド後に反映
cd ~/nix-config
nix flake update
nix build .#homeConfigurations.default.activationPackage --impure --no-link
home-manager switch --flake .#default --impure
```

直前世代へ戻すときは `home-manager generations` に表示された
一つ前の `/nix/store/...-home-manager-generation/activate` を実行する。

### 世代と Nix store の清掃

`home/nh.nix` で `programs.nh.clean` を有効にし、ユーザプロファイルと Nix store を週次で清掃する設定にしている。設定上の保持条件は `--keep-since 14d --keep 3`（直近14日と最低3世代）。macOS のシステムプロファイルの世代削除とは別で、削除済みの世代にはロールバックできない。

現在の `clean.extraArgs` は文字列で、macOS の生成済み LaunchAgent では `'--keep-since 14d --keep 3'` が一つの引数として渡っている。保持条件を正しく渡すには `home/nh.nix` で `extraArgs = [ "--keep-since" "14d" "--keep" "3" ];` への修正が必要。Linux の systemd では文字列が引数に分割される。

### dotfile の更新

`home/dotfiles/` や対応する `home/*.nix` を編集し、上記の switch で反映する。Git は `home/git.nix`、Alacritty・tmux・latexmk は `home/dotfiles.nix` が配置する。配置後のファイルは通常 Nix store へのリンクになるため、リポジトリ側を編集する。

Neovim はデフォルト設定で使う。外部設定リポジトリ、NvChad、lazy.nvim の復元は不要。`~/.ssh/config` はこのリポジトリの管理外なので、必要な接続先設定は各ホストで用意する。秘密鍵は Bitwarden SSH agent、API キー等は Nix 管理外のローカル設定で扱う。

既存ファイルと競合する初回適用では、macOS は `home-manager.backupFileExtension = "hmbak"`、Linux は `home-manager switch -b hmbak --flake ~/nix-config#default --impure` で退避する。同名のバックアップがある場合は内容を確認して別名へ移す。新しく追加した Nix モジュールや dotfile は、適用前に `git add <追加したファイル>` で追跡対象にする（`private/user.nix` は除く）。

### Homebrew 側 (cask は基本 nix-darwin 経由)

```bash
# 手動で cask を試す (継続使用するなら darwin/homebrew.nix へ追加)
brew install --cask <name>

# nix-darwin の宣言と実態を整合させたい時
sudo darwin-rebuild switch --flake ~/nix-config#default --impure  # cleanup = "uninstall" なので宣言外は消える
```

---

## 4. 何をどこで管理しているか

### Nix / Home Manager

主なパッケージは `home/default.nix` に定義する。アプリ設定を伴うものは各モジュールも参照。

- 基本CLI: ripgrep, fd, fzf, jq, bat, eza, coreutils, ncurses
- Git周辺: git, git-filter-repo, gh
- エディタ・端末: neovim（デフォルト設定）, vscode, Alacritty（`home/dotfiles.nix`）、Linux の Emacs（`home/emacs.nix`）
- シェル支援: tmux, direnv, nh。zsh / bash / starship は `programs.*` で設定
- 言語処理系: nodejs_26, typescript, pnpm, uv, pixi, SBCL, elan（Lean 4）
- ビルド: automake, cmake, meson, ninja, pkgconf, gnumake, gcc, lld, lldb, llvm
- 画像・動画・文書: ffmpeg, imagemagick, libwebp, poppler, yt-dlp, pandoc
- 暗号・パスワード: gnupg, age, bitwarden-cli
- その他: tree-sitter, sqlite, flyctl, aspell（英語辞書付き）
- LaTeX: texliveFull, ghostscript, tex-fmt
- LSP: lua-language-server, nil, nixd, pyright, rust-analyzer, typescript-language-server, astro-language-server, tailwindcss-language-server, texlab, clang-tools, marksman, dockerfile-language-server, yaml-language-server, bash-language-server, vscode-langservers-extracted
- Formatter / Linter: stylua, nixfmt, ruff, rustfmt, prettier, shellcheck, shfmt
- macOS のみ: lmstudio, prismlauncher, moonlight-qt, llvmPackages.openmp, docker-client, docker-compose（daemon は Docker Desktop Cask）
- Linux のみ: codex、`linux/default.nix` の hackgen-nf-font

fzf はパッケージのみ導入し、専用の Home Manager モジュールやシェル統合は宣言していない。direnv もパッケージのみで、`programs.direnv` は未設定。

### Linux GUI (`linux/flatpak.nix`)

Firefox・Chrome・Anki・Zotero・Bitwarden・LM Studio 等を Flatpak で管理する。
LM Studio は Nix 版で GPU を認識しないため、Linux では Flathub の
`ai.lmstudio.lm-studio`（コミュニティ管理版）を使用する。VS Code と Emacs は Nix 管理。
端末は Alacritty を macOS / Linux 共通で導入し、設定も共有する。

通常の `home-manager switch --flake ~/nix-config#default --impure` で反映する。
Flatpak 本体は dnf、残りの Flatpak アプリの追加と週次更新は nix-flatpak が担当する。

### Linux で Nix 外から導入したソフト

以下は Nix / Home Manager の管理外で別途導入している。

- Tailscale
- [gnome-shell-extension-appindicator](https://github.com/ubuntu/gnome-shell-extension-appindicator)

RDPの待受ポートは **3389/TCP**。firewalldの許可対象は **3389/TCP・UDP**。

### Linux GPU と CUDA の管理方針

Linux では **GPU / CUDA 一式を OS 側の SDK として dnf で管理し、汎用の開発ツールと個人の設定を Nix / Home Manager で管理する**。
普段使う CUDA 環境はホストごとに用意し、Home Manager のグローバル環境には汎用開発ツールを配置する方針とする。

| 対象 | 管理場所 | 理由 |
|---|---|---|
| NVIDIA カーネルドライバー | dnf | OS のカーネルと連携するため |
| ドライバーの `libcuda.so.1` | OS 側のドライバーを基準に管理 | カーネル側ドライバーと整合させるため |
| Docker / Podman・NVIDIA Container Toolkit | dnf | ホストのサービスやデバイスと連携するため |
| CUDA Toolkit（NVCC・CUDA ヘッダ） | dnf（対応する NVIDIA リポジトリ等） | ホスト共通の CUDA SDK として用意するため |
| CUDA ランタイムの `libcudart` | dnf | OS 側の CUDA Toolkit と揃えるため |
| cuBLAS・cuDNN 等の必要な CUDA 関連ライブラリ | dnf | CUDA SDK と同じ管理系統で依存関係を揃えるため |
| GCC / G++・Clang / clangd・CMake / Ninja 等の汎用開発ツール | Nix | 必要な版とツール構成を宣言し、別マシンへ持ち運ぶため |
| エディタ・LSP 設定・ドットファイル | Nix / Home Manager | 個人の開発環境を再現するため。SSH 接続設定はローカル管理、Neovim はデフォルト設定 |

**設計の意図**: 持ち運びたい個人の開発環境と、各ホストで用意する GPU / CUDA 基盤の境界を明確にする。
CUDA Toolkit・ヘッダ・ランタイム・関連ライブラリを dnf 側へまとめ、Nix で分かれている CUDA の構成要素から SDK の配置を組み立てる手間を抑える。
汎用開発ツールは既存の Nix 管理を活かし、CUDA のためだけにすべてを OS 側へ入れ直さない。
これは「ランタイムはすべて dnf」という分類ではなく、標準の CUDA SDK を一式で OS 側へ置く方針である。Nix 製ツール自身の実行時依存ライブラリは Nix に任せる。

**管理境界をまたぐ設定と運用**:

- **コンパイラの選択**: NVCC が対応する GCC / G++ の版を Nix 側で選ぶ。CUDA のドライバー要件と、NVCC のホストコンパイラ要件は別に確認する。CMake では `CMAKE_CUDA_COMPILER` と `CMAKE_CUDA_HOST_COMPILER` を初回構成時に明示し、通常の C++ 用の `CMAKE_CXX_COMPILER` も同じ対応版 G++ に揃える。Nix のラッパーやライブラリ検索先も含め、実ビルドで確認する。
- **clangd の連携**: Nix 版 clangd に `compile_commands.json` を渡し、必要に応じて `.clangd` で OS 側 CUDA の場所（`--cuda-path`）、標準ヘッダの検索先、NVCC 固有の引数を調整する。CUDA ファイルでの LSP 起動もエディタ側で設定する。dnf で SDK を導入しても、この連携がすべて自動設定されるわけではない。
- **プロジェクト固有の条件**: ソース一覧、マクロ、言語規格、GPU アーキテクチャは CMake 等で管理し、コンパイル情報を生成する。手元の RTX 2060 SUPER は Compute Capability 7.5 のため、対象にする場合の CMake 指定は `CMAKE_CUDA_ARCHITECTURES=75`、clangd 側は `--cuda-gpu-arch=sm_75` とする。
- **移行と更新**: `flake.lock` が固定するのは Nix 側の環境であり、dnf 側の CUDA までは固定しない。各ホストで導入時に使用したリポジトリ・パッケージと、動作確認したドライバー / CUDA / GCC / clangd の版を記録する。更新時は CMake のコンパイル情報を再生成し、ビルド・clangd の解析・GPU 実行を個別に確認する。
- **Nix パッケージの依存関係**: Nix 製の CUDA 対応アプリが dnf の CUDA ライブラリを自動利用するわけではない。そのパッケージが宣言する Nix 側の CUDA 依存は許容する。この方針は、自分で開発・ビルドする際の標準 CUDA 環境を対象とする。
- **別バージョンが必要な場合**: CUDA の版までプロジェクト単位で再現する必要が出た場合は、そのプロジェクトに専用の Nix `devShell` またはコンテナ環境を用意する。

既存の「Nix 版 GUI の GPU 連携」（[Linux のセットアップ手順](#fedora-など-dnf-系-linux-standalone-home-manager) 内）は併用する。Home Manager が Nix アプリ向けにドライバーライブラリを用意する場合も、NVIDIA の版は OS 側に合わせる。これは CUDA Toolkit の管理を Nix へ移すものではない。

現在の `linux/default.nix` には以下を宣言している。別ホストでは適用前に実環境へ合わせる。

- `targets.genericLinux.gpu.nvidia`: 有効、ドライバーバージョン `615.71.09` と対応ハッシュを固定
- `home.sessionPath`: `/usr/local/cuda-13.4/bin` を追加
- `CUDA_PATH`: `/usr/local/cuda-13.4`
- `CUDACXX`: `/usr/local/cuda-13.4/bin/nvcc`
- `CUDAHOSTCXX` / `NVCC_CCBIN`: Nix の `pkgs.gcc` が提供する `g++`
- `NIX_LDFLAGS_${pkgs.stdenv.cc.suffixSalt}`: NVIDIA 連携が有効な場合に `-rpath /run/opengl-driver/lib`

これらは既存 SDK の参照先を指定する設定で、CUDA SDK やカーネルドライバー自体はインストールしない。OS 側の版・配置とコンパイラの互換性は各ホストで確認する。

参考: [NVIDIA CUDA の構成と互換性](https://docs.nvidia.com/deploy/cuda-compatibility/why-cuda-compatibility.html)、[CUDA の導入・ホストコンパイラ要件](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)、[CMake のホストコンパイラ指定](https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_HOST_COMPILER.html)、[clangd の CUDA 対応](https://clangd.llvm.org/faq#does-clangd-support-cuda)。

### Homebrew (`darwin/homebrew.nix`)

- **Casks**: anki, bitwarden, blender, chatgpt, codex, discord, docker-desktop, emacs-plus-app, firefox（日本語）, font-hackgen-nerd, google-chrome, jetbrains-toolbox, kiwix, latexit, logi-options+, minecraft, multipass, pearcleaner, skim, slack, tailscale-app, thunderbird, tor-browser（日本語）, wireshark-app, zotero
- **Taps**: `d12frosted/emacs-plus`
- **Brews**: mole
- **適用時**: `autoUpdate = true` / `upgrade = true` / `greedyCasks = true`。`cleanup = "uninstall"` により宣言外の formula / cask を削除するため、継続利用するものは宣言へ追加する

JetBrains IDE の現在の導入窓口は Toolbox。`darwin/jetbrains-wrapper-fix.nix` は Nix 版 `jetbrains.*` の CLI ランチャー用 overlay として残っているが、現行の `home.packages` に JetBrains IDE 本体は含まれていない。

### Emacs

macOS の本体は Homebrew の `emacs-plus-app`、Linux は GNU 公式ソースの URL とハッシュを固定した **Emacs 31.1 PGTK**。Linux では Native Compilation と Tree-sitter を有効にし、全 Elisp の事前ネイティブコンパイルのみ無効化している。

`home/emacs.nix` が `init.el` / `early-init.el` を `~/.config/emacs/` と互換用の `~/.emacs.d/` に配置する。パッケージは Emacs の `package.el` / `use-package` で取得する。GNU / NonGNU ELPA を優先し、Evil は NonGNU-devel、lsp-mode / lsp-pyright は MELPA を使う。初回はパッケージや文法を取得するネットワーク接続が必要。

| 用途 | 現在の設定 |
|---|---|
| 編集・キー案内 | Evil、標準 WhichKey（`M-SPC`、待ち時間 0.4 秒） |
| 補完 | Corfu（2文字・0.15秒、`.` で開始）、Vertico |
| LSP / 診断 | lsp-mode + Corfu CAPF + Flymake、yasnippet |
| Python / Nix | Pyright + Ruff / nixd |
| Astro / Web | web-mode + Astro / Tailwind / ESLint。Astro はプロジェクトの TypeScript を使用 |
| Dockerfile / YAML | dockerfile-ts-mode / yaml-ts-mode + 対応 LSP |
| 構文解析 | Emacs 標準の Tree-sitter 文法自動取得 |
| Git | Magit（`C-x g`）、diff-hl |
| 端末 | Eat（`M-x eat`）、zsh / bash のシェル連携 |
| 配色 | `modus-operandi-tinted` |
| Common Lisp / スペルチェック | SLIME + SBCL / aspell + Flyspell |

`early-init.el` で `LSP_USE_PLISTS=true` を設定し、起動後の GC 閾値を 64 MiB にする。古い hash-table 形式でコンパイルされた lsp-mode が残っている場合は、同じ環境変数で再コンパイルする。接続確認は `M-x lsp-describe-session`、個別プロジェクトの Nix 開発環境でサーバーを起動する場合は `M-x lsp-nix` を使う。

デーモンは macOS で `darwin/default.nix` の LaunchAgent `org.nixos.emacs`、Linux で `linux/default.nix` の `services.emacs` が GUI ログイン時に起動する。macOS は `/bin/zsh -lic` 経由で普段の PATH を読み、Linux のサービスには Bitwarden の `SSH_AUTH_SOCK` を明示する。

```bash
# 常駐デーモンに接続
emacsclient -c -n   # GUI
emacsclient -t      # TUI

# macOS: 状態・ログ
launchctl print "gui/$(id -u)/org.nixos.emacs"
tail -n 50 ~/Library/Logs/emacs-daemon.error.log

# Linux: 状態・ログ
systemctl --user status emacs
journalctl --user -u emacs -n 50
```

`Emacs.app` や `emacs -nw` の通常起動は独立したプロセスになる。デーモンの設定を読み直すときはバッファを保存してから再起動する。

```bash
# macOS: KeepAlive のため、一旦登録を解除してから再登録する
launchctl bootout "gui/$(id -u)/org.nixos.emacs"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/org.nixos.emacs.plist"

# Linux
systemctl --user restart emacs
```

### Lean 4 / Emacs

`home/default.nix` で `elan` を導入し、Lean本体とビルドツールLakeの版を管理する。
`lean` / `lake` コマンドはelanが提供するため、別の `lake` パッケージは追加しない。
Lean本体はNix storeの外の `~/.elan/toolchains` に取得される。

初回はNix設定を適用してから、新しいターミナルで安定版のLeanを取得する。
macOSでは次を実行する（Linuxの適用方法は上記のHome Manager手順を参照）。

```bash
sudo darwin-rebuild switch --flake ~/nix-config#default --impure
elan default leanprover/lean4:stable
lean --version
lake --version
```

新しいプログラミング用プロジェクトの作成と実行:

```bash
mkdir -p ~/projects
cd ~/projects
lake new lean-playground exe
cd lean-playground
lake build
lake exe lean-playground
```

生成された `lean-toolchain` はGitに含め、プロジェクトで使うLeanの具体的な版を固定する。
既存プロジェクトでは、そのファイルに指定された版をelanが自動で取得・選択する。

Emacsを再起動し、`C-x C-f` でプロジェクト内の `Main.lean` を開く。
`lean4-mode` はEmacs標準の `package-vc` でGitHubから導入し、`.lean` に自動適用する。
初回の取得にはネットワーク接続が必要。
`lean4-mode` は直近リリースを取得する設定で、具体的なコミットは固定していない。Lean 用の操作は同モードが提供する。

| 操作 | キー / コマンド |
|------|----------------|
| 証明のゴール・エラー表示 | `C-c C-i` (`lean4-toggle-info`) |
| Lakeでビルド | `C-c C-p C-l` (`lean4-lake-build`) |
| importした依存を再読み込み | `C-c C-d` |
| Leanの版を確認 | `M-x lean4-show-version` |

例えば `Main.lean` に `#eval (List.range 5).map (fun n => n * n)` を追加すると、
評価結果は `[0, 1, 4, 9, 16]` になる。

参考: [Elan公式マニュアル](https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Managing-Toolchains-with-Elan/)、[lean4-modeの導入・操作](https://github.com/leanprover-community/lean4-mode)。

### VS Code: Emacs / Evil 風のキー操作

`home/vscode.nix` と `home/vscode-settings.json` で VSCodeVim とキー割り当てを管理する。文字編集は Normal / Insert / Visual のモードを使い、ファイル・バッファ・ウィンドウ操作には Emacs のキーを追加している。

| 操作 | キー |
|---|---|
| 移動・挿入・範囲選択 | `h/j/k/l`、`i/a/o`、`v/V/C-v` |
| 削除・コピー・貼り付け・繰り返し | `d/y/p`、`.`、`ciw` などのテキストオブジェクト |
| Undo / Redo、半画面スクロール | `u` / `C-r`、`C-u` / `C-d` |
| ファイルを開く・保存・別名保存 | `C-x C-f` / `C-x C-s` / `C-x C-w` |
| バッファを切り替える・閉じる | `C-x b` / `C-x k` |
| 上下・左右に分割 | `C-x 2` / `C-x 3` |
| 分割を一つにまとめる・次の分割へ | `C-x 1` / `C-x o` |
| Git の変更を VS Code の SCM で表示 | `C-x g` |
| コマンドパレット | `M-x` |
| メニューや補完を閉じる・編集時に Normal へ戻る | `C-g` |

`C` は Control、`M` は Alt（macOS では Option）。`C-x C-s` などは通常の VS Code キーバインドとして実行する。WhichKey 拡張や `M-SPC` の割り当ては現在宣言していない。

現在の Evil 設定に合わせ、`C-u` は Normal で上スクロール、`Tab` は補完・インデントに使う。Insert 中は `C-b` / `C-f` で左右移動できる。Vim のコピーはシステムクリップボードと共有する。統合ターミナルはシェル側のキー操作を使い、既存の `Shift+Enter`（ESC + CR）も維持する。

通常の Nix 設定適用後に VS Code を再起動する。macOS の文字キー長押しによる移動は `darwin/defaults.nix` の VS Code 専用 `ApplePressAndHoldEnabled = false` で有効にする。

### VS Code の設定・拡張管理

本体は `home/default.nix`、拡張・キー割り当て・C++ スニペットは `home/vscode.nix`、User 設定は `home/vscode-settings.json` で管理する。`mutableExtensionsDir = false` で、VS Code 本体と拡張の自動更新も無効化している。変更は Nix の宣言に追加して switch する。

Python / Jupyter、C/C++ / CMake、Java、Rust、LaTeX、Astro、Tailwind、ESLint、Nix、Remote SSH / Containers、VSCodeVim 等を宣言している。ESLint は `vscode-marketplace-release`、cpptools 本体は `pkgs.vscode-extensions`、その他は主に `vscode-marketplace` を使用する。具体的な版は `flake.lock` に依存する。

配色は Solarized Light、フォントは HackGen Console NF。保存時整形を有効にし、LaTeX は `tex-fmt` を使う。Prettier の VS Code 拡張は宣言していない。Web プロジェクトの TypeScript・ESLint・Tailwind 等の依存と Workspace 設定は各プロジェクトで管理する。

### Flatpak (`linux/flatpak.nix`)

- **両 Linux アーキテクチャに宣言**: Anki, Bitwarden, Google Chrome, Firefox, Kiwix, LM Studio, Zotero
- **x86_64のみ**: Blender, Discord, Slack
- `uninstallUnmanaged = true` により、ユーザ単位で導入した宣言外Flatpakを削除
- activation時更新は無効。アプリ更新は週次のsystemd user timerで実行
- Firefox のプロファイルは Flatpak の標準領域で管理し、専用 override は設定しない
- WiresharkはFlathub版にパケットキャプチャ機能がないため対象外

### Kiwix と Wiki データ

本体は macOS では [Homebrew Cask `kiwix`](https://formulae.brew.sh/cask/kiwix)、Linux では
[Flathub `org.kiwix.desktop`](https://github.com/flathub/org.kiwix.desktop) で管理する。
通常の `darwin-rebuild switch` / `home-manager switch` で導入される。
現時点では本体だけを宣言しており、Wiki データの自動ダウンロードは行わない。
[Kiwix Library](https://library.kiwix.org/) で言語・内容・容量を確認し、ZIM ファイルを選ぶ。
ZIM はオフライン閲覧用のスナップショットで、更新時は新しい版を取得する。

Wiki データも宣言的に管理できる。方法は次の2つ。

- **Nix store に固定する**: 日付入りの ZIM URL と SHA-256 を `pkgs.fetchurl` に指定し、
  Home Manager の `home.file` で閲覧用パスにリンクする。URL とハッシュを変更して更新する。
  旧世代が参照する ZIM も GC までは残るため、大容量の Wikipedia では更新時の空き容量に注意する。
  配布元が旧版を削除する場合に備え、長期の再取得には自分での保存・ミラーも必要になる。
- **Nix store の外に保存する**: 取得対象の URL・ハッシュ・保存先と同期コマンドを Nix で定義し、
  ZIM 本体は専用ディレクトリや外付け SSD に置く。大容量データ向けだが、ハッシュ検証、
  ダウンロード再開、旧版の扱いを同期処理側で実装する必要がある。

前者の設定例（未適用。`url` と `hash` は選んだ ZIM の実値に置き換える）：

```nix
# Home Manager モジュール内（pkgs を引数で受け取る）
home.file."Documents/Kiwix/wikipedia-ja.zim".source = pkgs.fetchurl {
  url = "https://download.kiwix.org/zim/wikipedia/<日付入りのファイル名>.zim";
  hash = "sha256-<ZIM の SHA-256 を base64 で記載>";
};
```

取得後は Kiwix でそのファイルを開く。ファイルの配置とアプリ内のライブラリ登録は別の操作になる。
Linux の Flatpak でこのリンクを直接参照させる場合は、保存先とリンク先 `/nix/store` の
読み取り権限を `linux/flatpak.nix` の Kiwix 用 override に追加する。
参照: [Nixpkgs の `fetchurl`](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-fetchers-fetchurl)。

### dotfile (`home/dotfiles/`)

- `gitconfig`: ユーザー名・メール・デフォルトブランチ。既存のcredential helper無効化も維持
- `tmux.conf`, `latexmkrc`: `~/.tmux.conf` / `~/.latexmkrc` へ配置。Alacritty 本体・設定・テーマも macOS / Linux 共通で導入
- Alacritty: HackGen Console NF 16pt、130列×28行、不透明背景。macOS では左右 Option を Alt として使う。配色は `github_dark_high_contrast` を Home Manager で読み込む
- `TERM=xterm-256color` は Alacritty の `[env]` だけで設定し、SSH 先に専用 terminfo を要求しない。tmux 内は従来どおり `screen-256color`
- 行間は `font.offset.y=8`。Retina (2x)・16pt を基準にしているため、DPI や文字サイズを変えた場合は調整する
- SSH 接続設定はローカル管理、Neovim はデフォルト設定。秘密鍵は Bitwarden SSH agent 管理

設定項目は [Alacritty 公式ドキュメント](https://alacritty.org/config-alacritty.html) を参照。

### システム設定 (`darwin/defaults.nix`)

- Dock: autohide=off, mineffect=genie, tilesize=60, mru-spaces=off, show-recents=off
- Finder: AppleShowAllExtensions=true, FXPreferredViewStyle="icnv"
- WindowManager (Stage Manager): GloballyEnabled=false (無効化済み)
- トラックパッド: Clicking=off, ThreeFingerDrag=off, RightClick=on
- 時計: ShowAMPM=true, ShowDate=0 (when space allows), ShowDayOfWeek=true
- 外観: AppleInterfaceStyle=Dark, reduceTransparency=on, increaseContrast=on
- Screencapture: style=window, 保存先 ~/Pictures/Screenshots
- NSGlobalDomain: AppleSpacesSwitchOnActivate=true 等
- 内蔵キーボード: Caps Lock / 左 Control を交換し、ログイン時に `hidutil` で再適用。外部キーボードには交換を適用しない
- ショートカット: `darwin/symbolic-hotkeys.nix` で管理。Control+Space と F11 の OS 側割り当てを無効化
- DNS: Wi-Fi / Thunderbolt Ethernet に Cloudflare の IPv4 / IPv6 DNS を設定
- それ以外 (Multitouch ジェスチャ等) は `CustomUserPreferences` で plist 直書き

---

## 5. 移行履歴

以前の GNU Stow + Brewfile から Nix / nix-darwin へ移行し、dotfile の管理も Home Manager に集約した。途中で使っていた chezmoi は削除済み。Neovim は外部設定を使う運用からデフォルト設定へ変更した。

現在のエディタ設定は Emacs と VS Code をこのリポジトリで管理する。端末は Alacritty、シェルの多重化は tmux を使う。Zed・Zellij・espanso・llama.cpp サーバー常駐の宣言は削除済み。

移行時の参考資料は [`nix-macos-guide.md`](./nix-macos-guide.md) に残している。過去の構成を含むため、現行の導入・更新手順はこの README と各 Nix ファイルを参照する。

---

## 6. 新マシンセットアップ手順

Bitwarden にログインして SSH agent を利用できることを確認する。`private/user.nix`、必要な SSH 接続設定や API キー、アプリのデータは Git 管理外なので別途用意する。Neovim の設定リポジトリを取得する作業は不要。

### macOS の初回セットアップ

Apple Silicon を前提とする。初回 switch の前に [Homebrew](https://brew.sh/) を導入し、`/opt/homebrew/bin/brew` が使える状態にする。この構成は Homebrew 自体のインストールは行わない。

```bash
# 1. Xcode CLT
xcode-select --install

# 2. Nix をインストール（完了後は新しいターミナルを開く）
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes

# 3. Homebrew 導入後、Bitwarden を用意してログイン・SSH agent を有効化
brew install --cask bitwarden
export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
ssh-add -l

# 4. リポジトリとホスト固有情報を用意
git clone git@github.com:<your-account>/nix-config.git ~/nix-config
cd ~/nix-config
cp private/user.nix.example private/user.nix
vi private/user.nix
# username: whoami / hostname: scutil --get LocalHostName
# system: "aarch64-darwin"
# private/user.nix は Git 管理外のままにする

# 5. 初回適用
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#default --impure

# 6. ログインシェルを再読み込み
exec zsh -l
```

2回目以降は `sudo darwin-rebuild switch --flake ~/nix-config#default --impure` を使う。初回起動方法は [nix-darwin の導入手順](https://github.com/nix-darwin/nix-darwin#step-2-installing-nix-darwin) を参照。App Store サインイン、Bitwarden のログイン、プライバシー権限は手動で設定する。

### Fedora など dnf 系 Linux (standalone Home Manager)

対象は systemd を使い、`nix` / `nix-daemon` パッケージを
標準リポジトリまたは EPEL から導入できる Fedora / Rocky Linux /
AlmaLinux などの `x86_64` または `aarch64` 環境。Home Manager はユーザ環境と
ユーザ単位の Flatpak だけを管理し、OS 自体のパッケージ、SELinux、
ファイアウォール等は引き続き dnf 側で管理する。

GPU / CUDA を使うホストでは、[Linux GPU と CUDA の管理方針](#linux-gpu-と-cuda-の管理方針) に従ってドライバー・CUDA SDK・必要なコンテナ基盤を dnf 側で別途用意する。以下の Home Manager セットアップだけでは、これらは導入されない。

> `linux/flatpak.nix` は `uninstallUnmanaged = true` のため、初回適用時に
> 宣言にない **ユーザ単位** Flatpak を削除する。必要なアプリは
> 先に `linux/flatpak.nix` へ追加する。システム単位の Flatpak には影響しない。

```bash
# 0. Nix がディストリビューションのリポジトリにあることを確認
#    Rocky Linux / AlmaLinux / RHEL では、必要に応じて先に EPEL を有効化する
dnf info nix nix-daemon

# 1. Nix と OS側の前提パッケージを dnf で導入
sudo dnf install -y \
  nix nix-daemon git flatpak xdg-desktop-portal xdg-desktop-portal-gtk
# KDE Plasma では GTK backend の代わりに、または追加で以下を使う:
# sudo dnf install -y xdg-desktop-portal-kde

# 2. multi-user daemon を有効化
sudo systemctl enable --now nix-daemon
# → ここで新しいログインシェルを開く

# 3. Nix、daemon、flake の動作確認
nix --version
# flakes が未有効なら ~/.config/nix/nix.conf に
# experimental-features = nix-command flakes を設定する
nix store ping
nix shell nixpkgs#hello --command hello

# 4. nix-config を取得
#    秘密リポジトリの場合は PAT または準備済みの SSH 鍵を使う
git clone https://github.com/<your-account>/nix-config.git ~/nix-config
cd ~/nix-config

# 5. ホスト/ユーザ情報を作成
cp private/user.nix.example private/user.nix
whoami
hostnamectl --static
uname -m
vi private/user.nix
# username: whoami と一致
# hostname: hostnamectl --static と一致
# system: uname -m=x86_64 なら "x86_64-linux"、aarch64 なら "aarch64-linux"

# 6. linux/default.nix の NVIDIA の版・ハッシュ、CUDA のパスをホストに合わせる
#    Mesa を使うホストでは nvidia.enable を false にする（後述）
#    private/user.nix は Git 管理外のままにする

# 7. 初回ビルドと適用
#    -b hmbak は既存の競合ファイルを *.hmbak へ一度だけ退避する
nix run home-manager/master -- switch \
  --flake ".#default" --impure -b hmbak

# 8. ログインシェルを再読み込みし、導入結果を確認
exec "$SHELL" -l
home-manager generations
flatpak list --user
systemctl --user list-timers '*flatpak*'

# 9. Bitwarden を起動してログイン・SSH agent を有効化
flatpak run com.bitwarden.desktop
# 新しいシェルで SSH_AUTH_SOCK と鍵の認識を確認
printenv SSH_AUTH_SOCK
ssh-add -l
```

`dnf info nix nix-daemon` で両パッケージが見つからない
ディストリビューションはこの手順の対象外。Fedora の構成例は
導入後の `/usr/share/doc/nix-core/README.fedora.md` でも確認できる。

初回適用で `programs.home-manager.enable = true` も有効になるため、
2 回目以降は通常ユーザで次だけを実行すればよい。

```bash
home-manager switch --flake ~/nix-config#default --impure
```

`sudo home-manager ...` は root のホームを対象にするため使わない。
Flatpak 本体と desktop portal は dnf、ユーザ用アプリ、Flathub remote、
週次更新 timer は `linux/flatpak.nix` が管理する。

#### Nix 版 GUI の GPU 連携（Mesa / NVIDIA）

Fedora のカーネル側 GPU ドライバーは OS 側で管理する。Nix 版 GUI が使う
描画ライブラリは Home Manager の GPU 連携で用意する。この設定は Fedora の
ドライバーをインストール・置換するものではない。

VS Code・Emacs・Alacritty を Nix 管理するため、GPU 連携を有効にしている。
現在は NVIDIA `615.71.09` を固定しているので、別ホストでは適用前に変更する。
Flatpak に移したアプリの描画ライブラリは Flatpak 側で管理される。

**Mesa を使う場合（nouveau など）**

`linux/default.nix` の既存の `targets.genericLinux` を次のように変更する。

```nix
targets.genericLinux = {
  enable = true;
  gpu = {
    enable = true;
    nvidia.enable = false;
  };
};
```

この Home Manager では、`genericLinux.enable = true` かつ nixGL 未設定なら
`gpu.enable` も既定で有効になる。上記では意図を明示している。
GPU 連携と既存の nixGL 設定は併用しない。

```bash
home-manager switch --flake ~/nix-config#default --impure
sudo "$HOME/.nix-profile/bin/non-nixos-gpu-setup"
```

セットアップは `/etc/tmpfiles.d/non-nixos-gpu.conf` を登録し、
`/run/opengl-driver` を Nix の GPU ライブラリ群へリンクする。
再起動時にもリンクが復元され、対象の Nix store パスは GC から保護される。
Fedora の `/usr/lib64` 全体を `LD_LIBRARY_PATH` に追加する手順ではない。

**NVIDIA 専用ドライバーを使う場合**

まず OS 側で NVIDIA ドライバーを導入して再起動し、`nvidia-smi` が正常に
動くことを確認する。既存の NVIDIA 設定を、ホストに対応する次の値へ更新する。
プレースホルダーは実際の値へ置き換えること。

```nix
targets.genericLinux = {
  enable = true;
  gpu = {
    enable = true;
    nvidia = {
      enable = true;
      version = "<OS側で動作中のドライバーバージョン>";
      sha256 = "<対応する配布ファイルのsha256-SRIハッシュ>";
    };
  };
};
```

`version` は **OS 側で動作中のドライバーと完全一致**させる。
`nvidia-smi` の「CUDA Version」ではなく「Driver Version」を使う。
ハッシュは同じバージョンの NVIDIA 配布ファイルから取得する。
現在の x86_64 ホストでの例（`.run` ファイルは実行しない）：

```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader
# 上で確認した値を入力
read -r -p 'NVIDIA driver version: ' nvidia_version
nix store prefetch-file --json \
  "https://download.nvidia.com/XFree86/Linux-x86_64/${nvidia_version}/NVIDIA-Linux-x86_64-${nvidia_version}.run"
```

出力の `hash` を `sha256` に設定する。aarch64 では URL 内の
`Linux-x86_64` を両方とも `Linux-aarch64` に変更する。
その後、Mesa の場合と同じ `home-manager switch` と
`sudo "$HOME/.nix-profile/bin/non-nixos-gpu-setup"` を実行する。
OS 側の NVIDIA ドライバーを更新したら、Nix 側のバージョン・ハッシュも更新し、
再適用・再セットアップする。通常の Nix 更新でも GPU ライブラリが変わり、
Home Manager が再セットアップを案内した場合は、そのコマンドを再実行する。

**確認と切り分け**

```bash
readlink -f /run/opengl-driver
ls /run/opengl-driver/share/glvnd/egl_vendor.d/
fc-match "HackGen Console NF"
```

フォント認識と GPU 描画の成功は別々に確認する。

手順と NVIDIA のバージョン一致条件は [Home Manager 公式マニュアル](https://nix-community.github.io/home-manager/usage/gpu-non-nixos.html) を参照する。実装を確認する場合は、`flake.lock` の `home-manager.locked.rev` に対応するソースを使う。

### Firefox の設定と拡張機能を別マシンへ移行

Nix構成ではFirefox本体の導入と更新だけを管理する。macOSはHomebrew Cask、LinuxはFlatpakを使い、プロファイルの作成・選択、設定、拡張機能はFirefox自身に任せる。プロファイル名や保存先、インストールIDをNixへ記録する必要はない。

端末間ではFirefox Syncの **アドオンと設定だけ** を同期する。従来どおり、Cookie、保存済みログイン、ログイン状態、履歴、セッション、サイトストレージは別マシンへ移行しない。

| 移行対象 | 移行方法 |
|---|---|
| Syncの対象となるFirefox設定 | Firefox Syncの「設定」を同期 |
| 同期されない設定・ツールバー配置・`about:config` | 必要なものだけ新しいマシンで手動設定 |
| Zotero Connector | 新しいマシンでZotero公式サイトから手動導入 |
| その他の拡張機能 | Firefox Syncの「アドオン」を同期し、不足分を手動導入 |
| 拡張機能固有の設定 | 拡張機能自身の同期機能またはエクスポート／インポート |
| Cookie、保存済みログイン、履歴、セッション等 | 移行しない |

Syncはすべての設定を複製するものではない。同期対象は[Mozilla公式ヘルプ](https://support.mozilla.org/en-US/kb/sync-custom-preferences)を参照する。キャッシュ容量やプロセス数などは通常Firefoxの既定値を使い、必要が生じた端末だけで調整する。

#### 1. 移行元で準備

1. FirefoxのSync設定で **アドオンと設定だけ** を有効にする。パスワード、履歴、開いているタブ、ブックマーク、住所、支払い方法等は無効にする。[同期対象の変更方法](https://support.mozilla.org/en-US/kb/how-do-i-choose-what-information-sync-firefox)を参照。
2. 「アドオンとテーマ」で使用中の拡張機能を確認し、同期されない設定やツールバー配置のうち、再現したいものを控える。
3. 拡張機能固有の設定が必要なら、それぞれの拡張機能が提供する同期機能を有効にするか、設定をエクスポートする。Firefox Syncで拡張機能本体が復元されても、内部のデータまで必ず同期されるとは限らない。

#### 2. 新しいmacOSで復元

1. [macOS のセットアップ](#macos-の初回セットアップ)を実行し、Homebrew版Firefoxを導入する。
2. `/Applications/Firefox.app` を起動する。初回プロファイルはFirefoxが作成する。
3. 移行元と同じMozillaアカウントへログインし、Syncは **アドオンと設定だけ** を有効にする。
4. Zotero公式サイトからZotero Connectorを導入し、Zoteroとの接続を確認する。
5. 不足している拡張機能と必要な設定だけを手動で追加する。エクスポートした拡張機能の設定があればインポートする。各サービスへのログインは新しいマシンでやり直す。

> 別マシンへの移行では `~/Library/Application Support/Firefox` 全体をコピーしない。Cookieやログイン状態などを持ち込まず、Firefox自身が新しいプロファイルを作成する。

#### 3. 新しいLinux（Flatpak）で復元

1. [Fedora など dnf 系 Linux](#fedora-など-dnf-系-linux-standalone-home-manager) の手順でFlatpak本体、desktop portal、Nix、Home Manager構成を導入する。Flathub remoteとユーザ用アプリは `nix-flatpak` が管理する。
2. `private/user.nix` の `system` がLinuxのCPUに合う `x86_64-linux` または `aarch64-linux` であることを確認し、構成を適用する。

   ```bash
   home-manager switch --flake ~/nix-config#default --impure
   ```

3. `flatpak run org.mozilla.firefox` で起動し、macOSと同様にSyncとZotero Connectorを設定する。

プロファイルはFlatpakの標準領域 `~/.var/app/org.mozilla.firefox/.mozilla/firefox/` にFirefox自身が作成する（[Mozillaの移行案内](https://support.mozilla.org/en-US/kb/install-firefox-linux#w_data-migration)）。ホストの `~/.mozilla/firefox` や `/nix/store` へアクセスする専用overrideは使わない。

#### 既存端末でHome Manager管理を解除する（一度だけ）

この手順は、以前の `home/firefox.nix` を適用済みの端末だけで行う。同じ端末の既存データを引き継ぐための手順であり、上記の別マシンへの移行とは異なる。**最初にFirefoxを完全に終了し、作業が終わるまで起動しない。**

**macOS**

1. `~/Library/Application Support/Firefox` をバックアップする。
2. `profiles.ini` がHome Managerへのシンボリックリンクなら、内容を保った書き込み可能な通常ファイルへ置き換える。これにより、次のswitchでも既存プロファイルの登録が残る。

   ```bash
   (
     set -eu
     firefox_registry="$HOME/Library/Application Support/Firefox/profiles.ini"
     if [ -L "$firefox_registry" ]; then
       firefox_registry_copy=$(mktemp "${firefox_registry}.XXXXXX")
       cp -L "$firefox_registry" "$firefox_registry_copy"
       chmod u+w "$firefox_registry_copy"
       mv -f "$firefox_registry_copy" "$firefox_registry"
     fi
   )
   ```

3. `sudo darwin-rebuild switch --flake ~/nix-config#default --impure` を実行する。旧 `Profiles/default/user.js` の管理リンクはHome Managerが削除する。`profiles.ini` の削除をスキップしたという警告は、手順2で通常ファイルにしたためで正常。
4. Firefoxを起動し、既存の設定や拡張機能を確認する。プロファイルが選ばれない場合は `about:profiles` から既存の `Profiles/default` を使うプロファイルを登録し、既定にする。インストールIDの手動編集は不要。

**Linux（Flatpak）**

1. ホストの `~/.mozilla/firefox` と、存在する場合は `~/.var/app/org.mozilla.firefox/.mozilla/firefox` をバックアップする。
2. 旧構成で使っていた `~/.mozilla/firefox` の内容を、Flatpakの標準領域 `~/.var/app/org.mozilla.firefox/.mozilla/firefox` へコピーする。コピー先が既にある場合は別名で退避してから行い、異なるプロファイル同士を混ぜない。
3. コピー先の `profiles.ini` はリンク先の内容を持つ書き込み可能な通常ファイルにする。コピーされた `default/user.js` は `user.js.disabled` に改名して、旧設定の強制適用を止める。元の `~/.mozilla/firefox` は確認が済むまで残す。
4. `home-manager switch --flake ~/nix-config#default --impure` を実行する。旧管理ファイルのリンクと、nix-flatpakが管理していたFirefox専用overrideが解除される。
5. `flatpak run org.mozilla.firefox` で通常起動を確認する。プロファイルが選ばれない場合は `about:profiles` で引き継いだプロファイルを既定にする。Flatpak内の表示パスは `~/.mozilla/firefox` でも、ホスト側の実体は手順2の標準領域にある。

**管理解除は設定値の初期化ではない。** `user.js` を外しても以前の値は `prefs.js` に残るため、既存端末では必要に応じてFirefoxの設定画面や `about:config` で変更・リセットする。プロファイル全体や `prefs.js` を削除する必要はない。設定ファイルの役割は[Mozillaの仕様](https://firefox-source-docs.mozilla.org/modules/libpref/index.html)を参照。

### 鍵が使えない場合のフォールバック

- **Bitwarden にログインできない**: SSH 鍵が取り出せない。新規 SSH 鍵を生成して GitHub の公開鍵を差し替える。

---

## 7. トラブルシュート

### `darwin-rebuild` がエラー

#### "system activation must now be run as root"

sudo を付けて再実行。

#### "Refusing to evaluate package ... because it has an unfree license"

`flake.nix` の `nixpkgs.config.allowUnfree = true;` が効いているか確認。

#### "Existing file ... would be clobbered"

home-manager がホームの既存ファイルを上書きできない。
→ `flake.nix` の `home-manager.backupFileExtension = "hmbak";` で自動退避される。
→ もしくは `mv conflict-file{,.bak}` で退避してから再 switch。

#### `flake.lock` が root 所有になる

`sudo darwin-rebuild` 実行時に root が touch することがある。

```bash
sudo chown $(id -u):staff ~/nix-config/flake.lock
```

#### GC が `fchmodat ... Operation not permitted` で失敗する

macOS の「アプリ管理」権限を確認する。コマンドを実行しているターミナル／エディタを許可し、そのアプリを再起動してから再実行する。

#### `vscode-extension-* removed on aarch64-darwin`

`ms-vscode.cpptools` 等の proprietary 拡張は `nix-vscode-extensions` 側で darwin から除外される。
本リポジトリでは nixpkgs 同梱の `pkgs.vscode-extensions.ms-vscode.cpptools` (unfree) で代替している (`home/vscode.nix` 参照)。`mutableExtensionsDir = false` なので GUI からの追加は反映されない — 拡張は必ず `vscode.nix` に書く。

#### `attribute 'foo' missing` / `option does not exist`

nix-darwin が知らないオプション名を `system.defaults.*` に書いた。
[MyNixOS](https://mynixos.com/) で正しい名前を検索するか、`CustomUserPreferences` に逃がす。

### `nix flake update` 後にビルドが壊れた

まず switch せず、対象 OS のビルドだけを実行して失敗したパッケージやオプションを確認する。

```bash
# macOS
nix build .#darwinConfigurations.default.system --impure --no-link --keep-going

# Linux
nix build .#homeConfigurations.default.activationPackage --impure --no-link --keep-going
```

`git diff -- flake.lock` で更新内容を確認し、上流の修正状況を調べる。必要に応じて動作していた lock に戻すか、対象パッケージだけを別リビジョンで固定する。

### `private/user.nix` を読み込めない

`~/nix-config/private/user.nix` が存在し、`username` / `hostname` / `system` を記入していることと、コマンドに `--impure` があることを確認する。現在の flake はこのファイルを絶対パスから読むため、Git への登録は不要。

`private/user.nix.example` に残る intent-to-add / skip-worktree の案内は旧方式のもの。新規セットアップではテンプレートをコピーして値を編集するだけでよい。`skip-worktree` は秘密情報をコミットから保護する仕組みではないため、強制追加せず `.gitignore` の対象として扱う。

### システム defaults が反映されない

```bash
killall Dock; killall Finder; killall cfprefsd
# または再ログイン
```

### Neovim に以前の設定が残っている

現在は Nix で本体だけを導入する運用。`nvim --clean` で標準設定の起動を確認し、通常起動との差がある場合は `~/.config/nvim` や `NVIM_APPNAME` 等を確認する。必要な内容を退避してから旧設定を整理する。Home Manager の switch は、管理対象にしていない古い Neovim 設定を削除しない。

---

## 8. 既知の制限

- **macOS のホスト依存**: `darwin/default.nix` の `hostPlatform` と Emacs の `/opt/homebrew` パスは Apple Silicon 前提。内蔵キーボードの LocationID、ネットワークサービス名も別マシンでは確認する
- **Linux のホスト依存**: NVIDIA の版・ハッシュと CUDA 13.4 の配置を固定している。OS 側の更新と合わせて変更する
- **外部で更新されるデータ**: Homebrew / Flatpak のアプリ、Emacs パッケージ、Tree-sitter 文法、elan のツールチェーンは Nix のロールバックだけでは以前の状態に戻らない
- **JetBrains overlay**: Nix 版 CLI ランチャー向けの対策が残っているが、現在は Toolbox を導入している
- **direnv 連携**: パッケージのみ導入し、`programs.direnv` / nix-direnv は未設定
- **手動セットアップ**: プライバシー権限、App Store / Bitwarden 等へのログイン、SSH 接続設定、アプリの可変データは別途用意する

---

## 参考リンク

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [home-manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager: standalone flake setup](https://nix-community.github.io/home-manager/nix-flakes/standalone.html)
- [NixOS/nix-installer](https://github.com/NixOS/nix-installer)
- [Fedora Packages: nix](https://packages.fedoraproject.org/pkgs/nix/nix/)
- [Fedora: Nix package tool](https://fedoraproject.org/wiki/Changes/Nix_package_tool)
- [nix-flatpak](https://github.com/gmodena/nix-flatpak)
- [nix-vscode-extensions](https://github.com/nix-community/nix-vscode-extensions)
- [MyNixOS (オプション横断検索)](https://mynixos.com/)
- 移行・構築時の参考資料（過去の構成を含む）: [`nix-macos-guide.md`](./nix-macos-guide.md) (リポジトリ直下)
- Sunshine + Moonlight: [`sunshine-moonlight.md`](./sunshine-moonlight.md)
