# nix-config — macOS / Linux 環境の宣言的管理

このリポジトリは、macOS では [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager)、Fedora など dnf 系 Linux では standalone Home Manager を使って環境を宣言的に管理するためのものです。dotfile は Home Manager で管理しています。SSH設定とNeovim設定は移行対象外とし、従来の配置・管理を維持します。chezmoi はこの2つのために残しています。

---

## 目次

1. [全体構成](#1-全体構成)
2. [リポジトリ構成](#2-リポジトリ構成)
3. [日常運用コマンド](#3-日常運用コマンド)
4. [何をどこで管理しているか](#4-何をどこで管理しているか)
5. [chezmoi の使い方](#5-chezmoi-の使い方)
6. [移行履歴 (Stow + Brewfile からの変更点)](#6-移行履歴)
7. [新マシンセットアップ手順](#7-新マシンセットアップ手順)
8. [トラブルシュート](#8-トラブルシュート)
9. [今後の TODO / 既知の制限](#9-今後の-todo--既知の制限)

---

## 1. 全体構成

```
┌────────────────────────────────────────────────────────────────┐
│ Nix (nix-darwin)       │ システム設定 + Homebrew統合 + 常駐サービス │
│  - system.defaults     │ Dock/Finder/トラックパッド等           │
│  - homebrew.casks      │ GUIアプリ (自己更新型・権限要求系)     │
│  - launchd.user.agents │ llama.cpp サーバ常駐 (darwin/llm.nix)  │
│  - bitwarden.nix       │ Bitwarden SSH agent (SSH_AUTH_SOCK)    │
├────────────────────────┼───────────────────────────────────────┤
│ Nix (home-manager)     │ macOS/Linux共通パッケージ + アプリ設定    │
│  - home.packages       │ CLI、LSP、VSCode / macOS GUI本体      │
│  - programs.*          │ zsh/bash/starship/fzf/zoxide/firefox/  │
│                        │ espanso/emacs/vscode/zed (拡張 + 設定) │
├────────────────────────┼───────────────────────────────────────┤
│ nix-flatpak (Linux)    │ GUIアプリ本体 + sandbox設定           │
│  - packages            │ Firefox/Chrome/Anki/Zotero等          │
│  - overrides           │ Home Manager設定へのアクセス権限      │
├────────────────────────┼───────────────────────────────────────┤
│ Home Manager          │ git / tmux / latexmk / ghostty         │
│ chezmoi                │ SSH・Neovimのみ (移行対象外)            │
│  - dot_ssh             │ SSH config のみ (鍵は Bitwarden 管理)  │
│  - .chezmoiexternal    │ NvChad 設定 (別リポジトリ)             │
├────────────────────────┼───────────────────────────────────────┤
│ Homebrew (Cask中心)    │ GUI Cask + mole                        │
│  - chrome, slack 等    │ 自己更新型・プライバシー権限系 GUI     │
│  - docker-desktop      │ 開発用コンテナの実行基盤              │
│  - claude-code, codex  │ AI CLI (更新が速いので brew 管理)      │
└────────────────────────┴───────────────────────────────────────┘
```

### Git リポジトリ

| 用途 | 場所 | リモート |
|---|---|---|
| Nix 設定 | `~/nix-config/` | (private) |
| dotfile | `~/.local/share/chezmoi/` | `git@github.com:tori3-po4/chezmoi-dotfiles.git` |
| Neovim 設定 | `~/.config/nvim/` (chezmoi external) | `git@github.com:tori3-po4/tori-NV-settings.git` |

---

## 2. リポジトリ構成

```
~/nix-config/
├── flake.nix            # 入力定義 + overlay + darwin/homeConfigurations
├── flake.lock           # ロックファイル (Nixが管理 / sudoで触ると root 所有になる)
├── .gitignore
├── README.md            # このファイル
├── sunshine-moonlight.md # WindowsゲームをMacへストリーミングする手順
├── nix-macos-guide.md   # Nix + macOS 全般の移行/構築ガイド
├── private/             # ホスト/ユーザ固有情報 (公開リポジトリで隠蔽するための隔離先)
│   ├── user.nix.example # 公開テンプレート (これだけ git 追跡)
│   └── user.nix         # 実情報 (各自で作成。intent-to-add + skip-worktree でコミットされない)
├── darwin/              # macOSシステム/ユーザレベル設定
│   ├── default.nix      # darwin/* を import するエントリポイント + zsh高速化等
│   ├── homebrew.nix     # Caskとmoleの宣言
│   ├── defaults.nix     # system.defaults (Dock, Finder, トラックパッド等)
│   ├── llm.nix          # llama.cpp サーバの launchd 常駐 (router mode, :8080)
│   ├── bitwarden.nix    # Bitwarden SSH agent を SSH_AUTH_SOCK に設定
│   └── jetbrains-wrapper-fix.nix  # JetBrains CLI ランチャーの日本語CWD問題対策 overlay
├── linux/               # Linuxユーザ環境固有の宣言
│   ├── default.nix      # linux/* を importするエントリポイント
│   └── flatpak.nix      # Flatpakアプリ、更新方針、sandbox override
└── home/                # home-manager (yourname 用)
    ├── default.nix      # home.packages 一覧 + 各モジュール import
    ├── emacs.nix        # macOS/Linux Emacs 31.1 + 共通 init.el
    ├── emacs/init.el    # ELPA優先、Evil(devel)/Corfu/Magit、lsp-mode(plist)
    ├── zellij.nix       # Emacsと干渉しない locked-mode キー設定
    ├── vscode.nix       # programs.vscode (拡張 + 設定 + スニペット)
    ├── vscode-settings.json  # VSCode の userSettings (JSON)
    ├── zed.nix          # programs.zed-editor (拡張 + LSP + task/debug)
    ├── zed-settings.json # Zed の userSettings (JSON)
    ├── cpp-snippets.json # VSCode/Zed 共有の C++ スニペット
    ├── zsh.nix / bash.nix    # シェル設定 (chezmoi から移行済み)
    ├── starship.nix / fzf.nix / zoxide.nix  # シェル支援ツール設定
    ├── firefox.nix      # Firefox プロファイル (profiles.ini / user.js) 生成
    ├── git.nix          # Nix git の credential.helper=osxkeychain 打ち消し
    └── espanso.nix      # services.espanso (スニペット展開)
```

### 各ファイルの役割

- **`flake.nix`**: インプット (依存リポジトリ) と、macOS 用の `darwinConfigurations.<host>` / `darwinConfigurations.default`、Linux 用の `homeConfigurations."<user>@<host>"` / `homeConfigurations.default` を定義。username/hostname/system は `private/user.nix` から読み込まれる。overlay (`nix-vscode-extensions` / llama.cpp の UI 無効化 / espanso のピン留め) と `nixpkgs.config.allowUnfree = true` もここで設定。
- **`private/user.nix`**: ホスト名・ユーザ名・アーキを保持する個人情報ファイル。`.gitignore` 対象だが `git add -N -f` で intent-to-add し、Nix flake から見えるようにする。`git update-index --skip-worktree` で誤コミットも防止。
- **`private/user.nix.example`**: 公開可能なテンプレート。新マシンでは `cp private/user.nix.example private/user.nix` から始める。
- **`sunshine-moonlight.md`**: Windows側SunshineとMac側MoonlightをTailscale経由で接続するセットアップ・運用手順。
- **`darwin/default.nix`**: `system.stateVersion` / `system.primaryUser` / チャネル無効化 / `/etc/zshrc` の compinit 無効化 (zsh 起動高速化)。darwin/* を import。
- **`darwin/homebrew.nix`**: Cask 宣言。`onActivation.cleanup = "uninstall"` + `autoUpdate`/`upgrade` = true + `greedyCasks = true` で、宣言外の cask は自動削除・自己更新型 cask も rebuild で更新。
- **`linux/flatpak.nix`**: `nix-flatpak` のユーザ用Flatpak宣言。Flathubのアプリ一覧、週次更新、宣言外パッケージの削除、Firefox/ZedからHome Manager管理設定を参照するsandbox overrideをLinux側へ集約。
- **`darwin/defaults.nix`**: macOS のあらゆる `defaults write` 相当を宣言。nix-darwin が公式オプションを持たない場合は `CustomUserPreferences` で plist 直書き。
- **`darwin/llm.nix`**: llama.cpp の OpenAI 互換サーバを router mode で launchd 常駐 (`:8080`)。複数 GGUF モデルをリクエスト時に自動ロード、アイドル時アンロード。
- **`home/default.nix`**: 共通CLIツールと VS Code を Nix で管理する。LM Studio・Prism Launcher・Moonlight・Ghostty は macOS のみに導入し、Ghostty の設定ファイルも macOS 限定。Linux の LM Studio は `linux/flatpak.nix`、Emacs は `home/emacs.nix` で管理する。
- **`home/emacs.nix` / `home/emacs/init.el`**: macOSのHomebrew Emacs PlusとLinuxのNix製Emacs 31.1 PGTKで共通の設定。GUIとTUI (`emacs -nw`) の両方で利用する。GNU/NonGNU ELPAを優先し、EvilはNonGNU-devel、lsp-modeとlsp-pyrightはMELPAに固定する。LSPはplist表現、補完はCorfu、診断はFlymakeを使う。LSPサーバーはNix、tree-sitter文法のダウンロード・コンパイルはEmacsが管理する。
- **`home/zellij.nix`**: 通常は locked mode で入力を Emacs/Evil へ通し、Emacs/Evil で未割当の `F12` でのみ Zellij 操作モードを出入りする。
- **`home/vscode.nix`**: `programs.vscode` (`package = null`、本体は home.packages 側) で拡張 + `userSettings` + スニペット。`mutableExtensionsDir = false` で完全宣言管理。darwin で配信されない `ms-vscode.cpptools` は nixpkgs 同梱版 (unfree) を使用。
- **`home/zed.nix`**: `programs.zed-editor` (`package = null`) で拡張、LaTeX/CMake task、debug、エディタ設定を宣言管理。本体はmacOSではHomebrew Cask、Linuxでは `nix-flatpak` が管理する。見た目・キーマップ・整形動作は VSCode に合わせ、C++ スニペットは両エディタで共有。
- **`home/zsh.nix` / `bash.nix` / `starship.nix` / `fzf.nix` / `zoxide.nix`**: シェルと周辺ツールの設定。以前は chezmoi (`.zshrc` 等) で管理していたが home-manager の `programs.*` に移行済み。
- **`home/firefox.nix`**: 本体を導入せず、Home Managerの `programs.firefox` だけで `profiles.ini`、Firefox上の「デフォルト」プロファイルの `user.js`、SpeedUpperを反映する共通設定。macOSの本体はHomebrew Cask、Linuxの本体とsandbox overrideは `linux/flatpak.nix` が担当する。about:configで変えても起動時に `user.js` の値へ戻る点に注意。

---

## 3. 日常運用コマンド

### Nix側

#### macOS (nix-darwin)

```bash
# 設定変更後の反映 (sudo 必須。--impure は private/user.nix を $HOME 起点で読むため必須)
sudo darwin-rebuild switch --flake ~/nix-config --impure

# 履歴確認
sudo darwin-rebuild --list-generations

# 直前世代に戻す (壊れた時)
sudo darwin-rebuild rollback

# 入力(リポジトリ)を最新に更新
cd ~/nix-config
nix flake update
# → 更新後は switch の前に必ずビルドが通るか確認する:
nix build .#darwinConfigurations.default.system --impure --no-link
# 壊れていたら「8. トラブルシュート → nix flake update 後にビルドが壊れた」参照

# Nix store のごみ掃除
sudo nix-collect-garbage -d
sudo darwin-rebuild switch --flake ~/nix-config --impure  # 起動可能世代を再確定
```

#### Zed 内蔵ターミナルから実行する場合

`darwin-rebuild` や Nix store の GC は、Home Manager がコピーした `.app` の更新・削除を伴う。
Zed 内蔵ターミナルから実行する場合は、macOS の「システム設定 → プライバシーとセキュリティ → アプリ管理」で **Zed** を許可してから、Zed を完全終了して起動し直すこと。
Zed 本体は公式 Developer ID 署名を保持する Homebrew Cask 版なので、通常は更新後も許可が引き継がれる。

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

# ユーザの Nix store 参照のごみ掃除
nix-collect-garbage -d
```

直前世代へ戻すときは `home-manager generations` に表示された
一つ前の `/nix/store/...-home-manager-generation/activate` を実行する。

### dotfile の更新

`home/dotfiles/` の設定を編集して、通常の Nix / Home Manager の switch で反映します。
Git設定は `home/git.nix`、Ghostty（macOSのみ）・tmux・latexmkrcの配置は `home/dotfiles.nix` で宣言しています。
SSH・Neovimは移行対象外です。Neovimだけをchezmoiで更新する場合は
`chezmoi apply ~/.config/nvim` と対象を指定します。

### Homebrew 側 (cask は基本 nix-darwin 経由)

```bash
# 手動で cask を試す (継続使用するなら darwin/homebrew.nix へ追加)
brew install --cask <name>

# nix-darwin の宣言と実態を整合させたい時
sudo darwin-rebuild switch --flake ~/nix-config --impure  # cleanup = "uninstall" なので宣言外は消える
```

---

## 4. 何をどこで管理しているか

### Nix (`home/default.nix`)
- 基本CLI: ripgrep, fd, fzf, jq, bat, eza, zoxide, coreutils
- Git周辺: git, git-filter-repo, lazygit, gh
- エディタ: neovim, vscode。Linux の Emacs も Nix 管理を維持
- macOS のみの GUI 本体: lmstudio, prismlauncher, moonlight-qt, ghostty-bin
- シェル支援: tmux, zellij, direnv, stow, chezmoi
- ローカルLLM GUI: LM Studio（macOS は Nix、Linux は Flatpak）
- 暗号/パスワード: gnupg, age, bitwarden-cli
- 言語処理系: deno, nodejs_22, uv, pixi, SBCL, elan (Lean 4), jdk, gradle
- ビルド: automake, cmake, meson, pkgconf, gnumake, gcc, lld, lldb, llvm, openmp
- 画像/動画/PDF: ffmpeg, imagemagick, libwebp, poppler, yt-dlp, pandoc
- コンテナ (macOS): docker-client, docker-compose (daemon は Docker Desktop cask)。Linux のコンテナ基盤は dnf 側で管理
- LaTeX: texlive (scheme-full), ghostscript, tex-fmt
- LSP: rassumfrassum (多重化), lua-language-server, nil, nixd, pyright, rust-analyzer, typescript-language-server, astro-language-server, tailwindcss-language-server, texlab, clang-tools, marksman, dockerfile-language-server, yaml-language-server, bash-language-server, vscode-langservers-extracted
- Formatter/Linter: stylua, nixfmt, ruff, rustfmt, prettier, shellcheck, shfmt
- programs.* 設定: zsh, bash, starship, fzf, zoxide, emacs, firefox (user.js), vscode, zed-editor, espanso

### Linux GUI (`linux/flatpak.nix`)

Firefox・Chrome・Anki・Zotero・Bitwarden・LM Studio 等を Flatpak で管理する。
LM Studio は Nix 版で GPU を認識しないため、Linux では Flathub の
`ai.lmstudio.lm-studio`（コミュニティ管理版）を使用する。VS Code と Emacs は Nix 管理。
Ghostty は macOS 専用とし、Linux には本体・設定ファイル・起動サービスを配置しない。

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
| エディタ・LSP 設定・ドットファイル | Nix / Home Manager | 個人の開発環境を再現するため。SSH・Neovim 設定は既存方針どおり chezmoi |

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

この節は管理方針であり、CUDA 一式の導入済み・動作確認済みを示すものではない。実際の導入と検証は各ホストで行う。

参考: [NVIDIA CUDA の構成と互換性](https://docs.nvidia.com/deploy/cuda-compatibility/why-cuda-compatibility.html)、[CUDA の導入・ホストコンパイラ要件](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)、[CMake のホストコンパイラ指定](https://cmake.org/cmake/help/latest/variable/CMAKE_LANG_HOST_COMPILER.html)、[clangd の CUDA 対応](https://clangd.llvm.org/faq#does-clangd-support-cuda)。

### Homebrew (`darwin/homebrew.nix`)
- **Casks**: anki, bitwarden, blender, chatgpt, claude-code@latest, codex, discord, docker-desktop, firefox, font-hackgen-nerd, google-chrome, latexit, llama-app, logi-options+, minecraft, multipass, pearcleaner, skim, slack, tailscale-app, wireshark-app, zed, zotero
- **Taps**: なし
- **Brews**: mole (gtkwave は必要になったら `randomplum/gtkwave` tap で復活させる)
- 運用: `cleanup = "uninstall"` / `autoUpdate` / `upgrade` / `greedyCasks` すべて有効

### Emacs 31.1

- macOSはHomebrewのEmacs Plus、LinuxはGNU公式 `emacs-31.1.tar.xz` をURLとSHA-256で固定した `emacs31-pgtk` を使う。
- macOSのdaemonは `darwin/default.nix` のユーザーLaunchAgent (`org.nixos.emacs`) でログイン時に起動する。`zsh -lic 'exec /opt/homebrew/bin/emacs --fg-daemon'` でログイン設定と `.zshrc` を読み、普段のシェルのPATHを引き継ぐ。PATHの別管理は不要で、`home.sessionPath` の変更にも追従する。補完やプロンプトの初期化もdaemon起動時に一度実行される。既存の `init.el` によるNixコマンド優先とLSP設定も維持する。
- daemonのGUIは `emacsclient -c -n`、TUIは `emacsclient -t` で開く。`Emacs.app` の通常起動は独立したEmacsを開くため、daemonに接続するときはEmacs Clientを使う。状態は `launchctl print "gui/$(id -u)/org.nixos.emacs"`、エラーは `~/Library/Logs/emacs-daemon.error.log` で確認する。`KeepAlive = true` のため終了後は再起動する。一時停止する場合はバッファを保存してから `launchctl bootout "gui/$(id -u)/org.nixos.emacs"`、再開は `launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/org.nixos.emacs.plist"` を使う。
- Native Compilation と Tree-sitter を有効にし、フルAOTのみ無効化。GUIに加えて `emacs -nw` によるTUI利用も維持する。
- 共通設定: `~/.config/emacs/init.el` と互換用 `~/.emacs.d/init.el`。GNU ELPA / NonGNU ELPA の安定版を優先し、EvilをNonGNU-devel、lsp-modeとlsp-pyrightをMELPAに固定。不足パッケージを起動時に自動導入し、既存の Evil が修正確認済みの `1.15.0.0.20260728.297` より古ければ開発版へ更新する。修正済みの版が入っていれば、この確認のための通信は行わない。
- LSP: lsp-modeを使い、補完はCorfuのCAPF、診断はFlymakeへ統合する。`lsp-completion-provider = :none` でCompanyの自動起動を止め、LSPのCAPFは有効にする。LSPのsnippet候補を展開できるよう、LSPバッファで `yas-minor-mode` を有効にする。C/C++、Python、Rust、JS/TS/TSX、HTML/CSS、シェル、Nixで `lsp-deferred` を自動起動する。Pythonはlsp-pyrightと同梱のlsp-ruffでPyright＋Ruffを併用し、Nixは `nixd` を選ぶ。`lsp-completion-no-cache = nil`、`lsp-log-io = nil`、受信上限1MiB、`process-adaptive-read-buffering = nil` を使う。
- plistとGC: `early-init.el` でパッケージの有効化前に `(setenv "LSP_USE_PLISTS" "true")` を設定する。起動後のGC閾値は64MiB、`gc-cons-percentage = 0.1`。既存のhash版は環境変数の追加だけでは変換されないため、lsp-modeとlsp-pyrightをplist設定で再コンパイルし、対応する古いnative compileキャッシュも更新する。現在の導入では両パッケージを再ビルド済み。新規導入・更新時のコンパイルもearly-initの環境変数を継承する。[公式の設定手順](https://emacs-lsp.github.io/lsp-mode/page/performance/#use-plists-for-deserialization)も参照。
- 自動補完: Corfuは通常2文字入力し、入力が0.15秒止まったら表示する。`.` の直後はメンバー補完をすぐ開始する（`corfu-auto-trigger = "."`）。`M-TAB` の手動補完は開始文字数を待たずに使える。これは要求頻度の調整であり、1回の応答サイズや絞り込み処理自体を高速化する設定ではない。
- 複数LSP: lsp-modeのadd-onクライアントで複数サーバーへ直接接続する。`rass` は比較検証用に残す。`M-x lsp` が通常の接続コマンド。既存の `M-x lsp-nix` もlsp-modeへ切り替え、指定した `nix develop` 環境で任意のサーバーコマンドを起動できる。
- Web編集: `.astro` はNonGNU ELPAの `web-mode` で開き、言語IDを `astro` として自動接続する。Astro・Tailwind・ESLintはNixの実行ファイルを直接使う。Tailwind v4の初回起動判定と動的補完登録への互換ガード、ESLintのAstro有効化を設定する。Astroはプロジェクト内の `node_modules/typescript/lib` を使い、TRAMPではサーバー側のパスに変換する。`typescript-sdk` リンクや `.dir-locals.el` の起動用evalは不要。
- Tree-sitter: Emacs 31標準の `treesit-enabled-modes` と `treesit-auto-install-grammar` を使い、TS/TSX・CSS等の対応ファイルを初めて開いたときに必要な文法を自動取得・コンパイルする。保存先は利用中のEmacs設定ディレクトリ内の `tree-sitter/`。Astroファイル自体はweb-modeの構文解析を使うため、Astro専用文法や `treesit-auto` 等の追加管理パッケージは不要。手動で再導入する場合は `M-x treesit-install-language-grammar` を使う。
- 配色: `modus-themes` を `use-package` で GNU ELPA から導入し、Zed の `Gruvbox Light Soft` に近い暖色系のライトプリセット `modus-operandi-tinted` を使う。face と ANSI 色はテーマ標準に任せる。
- Git変更表示: GNU ELPA の `diff-hl` で追加・変更・削除の印を行の左側の余白に表示する。GUI/TUIの両方に対応し、未保存の編集とMagitでの操作にも追従する。
- ELPA本体とquickstartはEmacsメジャー別に保存し、32で生成したbyte-codeを31から読まない。
- TUI: Emacs 31標準の tty child frame をCorfu 2.xが自動検出するため `corfu-terminal` は不要。
- Zellij: locked mode を既定とし、`F12` 以外のキー入力を Emacs に通す。`F12` で Zellij の normal/locked mode を切り替える。

Dockerfile / Compose:

`Dockerfile`（`Dockerfile.dev` 等を含む）と `Containerfile` は標準の `dockerfile-ts-mode`、`.yaml` / `.yml` は標準の `yaml-ts-mode` を使い、既存のTree-sitter設定で文法を自動取得する。両モードで `lsp-deferred` を自動起動し、Nixの `dockerfile-language-server`（実行名 `docker-langserver`）と `yaml-language-server` へ接続する。

Compose等のYAMLスキーマは、YAML Language Serverの既定のSchemaStore連携による自動判定・取得に任せる。Emacs設定ではスキーマURLやファイル名の対応を手書きしない。自動適用の対象はSchemaStoreのカタログに従い、取得時はネットワーク接続が必要。

確認用:

Nix設定を通常の手順で適用してEmacsを再起動し、Astro・Python・Nixのプロジェクトを開く。`M-x lsp-describe-session` で接続を確認する。`M-: (list (getenv "LSP_USE_PLISTS") lsp-use-plists (lsp-make-position :line 0 :character 0) gc-cons-threshold)` が `("true" "true" (:line 0 :character 0) 67108864)` 相当になれば、plistのプロトコル生成も有効（`lsp-use-plists` は非nilでよい）。調査時だけ `lsp-log-io` を有効にし、`M-x lsp-workspace-show-log` を使う。旧Eglotプロセスと混在させないため、設定の再評価だけでなくEmacsを再起動する。

Astro・Tailwind・ESLint の実サーバーを使った2,160回の測定では、plist＋GC 64MiBのTailwind補完は中央値119〜140ms、キャッシュ後は12〜14msだった。これは描画とCorfuのauto-delayを除いた値。通常設定への採用はこの結果に基づく。

```bash
emacs --version
emacs --batch --eval '(princ (native-comp-available-p))'
emacs --batch --eval "(princ (featurep 'tty-child-frames))"
emacs --batch --eval '(princ system-configuration-options)'
```

### Lean 4 / Emacs

`home/default.nix` で `elan` を導入し、Lean本体とビルドツールLakeの版を管理する。
`lean` / `lake` コマンドはelanが提供するため、別の `lake` パッケージは追加しない。
Lean本体はNix storeの外の `~/.elan/toolchains` に取得される。

初回はNix設定を適用してから、新しいターミナルで安定版のLeanを取得する。
macOSでは次を実行する（Linuxの適用方法は上記のHome Manager手順を参照）。

```bash
sudo darwin-rebuild switch --flake ~/nix-config --impure
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
`lsp-deferred` で自動接続し、既存のlsp-mode / Corfu / Flymake設定で補完・診断を使える。
LSPが接続されていなければ `M-x lsp` を実行する。

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

`home/vscode.nix` と `home/vscode-settings.json` で VSCodeVim と WhichKey を管理する。文字編集は Normal / Insert / Visual のモードを使い、ファイル・バッファ・ウィンドウ操作には Emacs のキーを追加している。

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
| コマンドパレット・キー案内 | `M-x` / `M-SPC` |
| メニューや補完を閉じる・編集時に Normal へ戻る | `C-g` |

`C` は Control、`M` は Alt（macOS では Option）。`M-SPC` でキー案内を開き、`C-x` で追加した操作の一覧に進める。案内は400 ms後に表示される。直接 `C-x C-s` などを押す場合は通常の VS Code キーバインドとして実行する。

現在の Evil 設定に合わせ、`C-u` は Normal で上スクロール、`Tab` は補完・インデントに使う。Insert 中は `C-b` / `C-f` で左右移動できる。Vim のコピーはシステムクリップボードと共有する。統合ターミナルはシェル側のキー操作を使い、既存の `Shift+Enter`（ESC + CR）も維持する。

通常の Nix 設定適用後に VS Code を再起動する。macOS の文字キー長押しによる移動は `darwin/defaults.nix` の VS Code 専用 `ApplePressAndHoldEnabled = false` で有効にする。

### VS Code: Astro / Next.js / Tailwind の確認（2026-09-06）

`home/vscode.nix`、`home/vscode-settings.json` と実機の既定プロファイルを確認した。確認時点の `code --list-extensions --show-versions` は宣言した25拡張と一致し、実機のUser設定もJSONとして一致した。その後、ESLint安定版をNixの宣言に追加した（計26拡張、通常のNix switchで反映）。その他は以下の検証結果と追加案の段階。対象プロジェクトは指定されていないため、プロジェクト依存・Workspace設定・実際の補完/診断動作は未検証。

| 用途 | 現状 | 判断・最小案 |
| --- | --- | --- |
| Astro | `astro-build.astro-vscode@2.0.12` 導入済み | 公式拡張の選択は適切。ただし同梱CHANGELOGの先頭が `2.0.0-next.12`、Prettier依存が2系の旧プレリリースなので、まず安定版へ切り替える。 |
| Next.js / React / TSX | VS Code標準のJS/TS支援を利用 | 補完・型診断・基本整形・デバッグは標準機能で揃う。Next.js専用拡張は必須ではない。Next.jsのTSプラグインにはWorkspace版TypeScriptの選択が必要。 |
| Tailwind | `bradlc.vscode-tailwindcss@0.15.10` 導入済み | v3/v4に対応。`class`、`className`、`class:list` は既定の対象。文字列内の自動補完設定は未設定。 |
| ESLint | `pkgs.vscode-marketplace-release.dbaeumer.vscode-eslint` を宣言に追加（3.0.34） | プロジェクトのESLint設定に従って編集中のlint診断・修正を提供。型診断とは別の機能。 |
| Prettier | `esbenp.prettier-vscode` 未導入、`editor.formatOnSave = true` | Astro公式拡張は整形機能を含み、JS/TSも標準整形がある。統一したPrettier整形やTailwindクラスの自動整列が必要な場合だけ追加。Nixの `prettier` CLIだけではVS Codeの整形プロバイダーにならない。 |

根拠: [Astro公式のエディタ設定](https://docs.astro.build/en/editor-setup/)、[VS CodeのTypeScript機能](https://code.visualstudio.com/docs/languages/typescript)、[Next.jsのIDEプラグイン](https://nextjs.org/docs/app/api-reference/config/typescript#ide-plugin)、[Tailwind CSS IntelliSense公式説明](https://github.com/tailwindlabs/tailwindcss-intellisense)、[ESLint拡張](https://github.com/microsoft/vscode-eslint)、[Prettier拡張](https://github.com/prettier/prettier-vscode)。

**Astroの版選択を直す最小案**: 現在の `pkgs.vscode-marketplace` は[プレリリースを優先する](https://github.com/nix-community/nix-vscode-extensions#vscode-marketplace-and-open-vsx)。このlockではAstroの `2.0.12` が選ばれる一方、`pkgs.vscode-marketplace-release.astro-build.astro-vscode.version` は `2.16.17` と評価できた。既存リストの `astro-build.astro-vscode` を外し、後続の `++ [ ... ]` 内に次を置けば、他拡張の選択やlockを変えずに修正できる。拡張の自動更新は無効、拡張ディレクトリも宣言管理なのでNix側で変更する。

```nix
pkgs.vscode-marketplace-release.astro-build.astro-vscode
# Prettierで整形を統一する場合のみ（現在のlockでは12.4.0）:
pkgs.vscode-marketplace-release.esbenp.prettier-vscode
```

**拡張を増やさずに補える設定**: 各Webプロジェクトの `.vscode/settings.json` に、必要な項目を追加する。Tailwind専用CSSの関連付けはプロジェクト内に限定する。

```json
{
  "editor.quickSuggestions": { "strings": "on" },
  "files.associations": { "*.css": "tailwindcss" },
  "[astro]": { "editor.defaultFormatter": "astro-build.astro-vscode" }
}
```

- Next.js: `tsconfig.json` の `compilerOptions.plugins` に `{ "name": "next" }` があることを確認し、TS/TSXファイルを開いて `TypeScript: Select TypeScript Version` → `Use Workspace Version` を選ぶ。Nixで導入したグローバル `tsc` とは別に、プロジェクトの依存と設定を使う。
- Tailwind: プロジェクトに `tailwindcss` を導入し、v4では `@import "tailwindcss";` を含む `.css`、v3では `tailwind.config.*` 等を用意する。`cn()` / `clsx()` / `cva()` 内でも補完したい場合は、使用する関数だけ `"tailwindCSS.classFunctions": ["cn", "clsx", "cva"]` に指定する。この設定は導入済み0.15.10にも存在する。検出に失敗するときは `Tailwind CSS: Show Output` を確認し、複数ルートの場合にだけCSS/設定ファイルの明示を検討する。
- ESLint: 拡張だけでなく、Next.jsではプロジェクトの `eslint` / `eslint-config-next` とESLint設定、Astroでは必要に応じて `eslint-plugin-astro` とその設定を用意する。保存時修正を望む場合は `"editor.codeActionsOnSave": { "source.fixAll.eslint": "explicit" }` を設定する。[Next.jsのESLint設定](https://nextjs.org/docs/app/api-reference/config/eslint)、[Astro用ESLintプラグイン](https://ota-meshi.github.io/eslint-plugin-astro/user-guide/)。
- Tailwindクラスの自動整列: 追加のVS Code拡張を多数入れる必要はなく、プロジェクトのPrettier 3と `prettier-plugin-tailwindcss` で対応する。Astroも整形するなら `prettier-plugin-astro` を加え、Tailwindプラグインを最後に置く。Tailwind v4ではPrettier設定に `tailwindStylesheet` を指定する。Prettier拡張を使う場合はJS/TS/TSX/Astro等の対象言語ごとに既定フォーマッターを `esbenp.prettier-vscode` へ変更する。[Tailwind公式Prettierプラグイン](https://github.com/tailwindlabs/prettier-plugin-tailwindcss)。

### Flatpak (`linux/flatpak.nix`)

- **全アーキテクチャ**: Anki, Bitwarden, Google Chrome, Firefox, LM Studio, Zed, Zotero
- **x86_64のみ**: Blender, Discord, Slack
- `uninstallUnmanaged = true` により、ユーザ単位で導入した宣言外Flatpakを削除
- activation時更新は無効。アプリ更新は週次のsystemd user timerで実行
- Firefox/Zedはoverrideを通じて `home/firefox.nix` / `home/zed.nix` の設定を利用
- WiresharkはFlathub版にパケットキャプチャ機能がないため対象外

### dotfile (`home/dotfiles/`)

- `gitconfig`: ユーザー名・メール・デフォルトブランチ。既存のcredential helper無効化も維持
- `tmux.conf`, `latexmkrc`: 元の設定内容をそのまま配置。`ghostty.conf` は macOS のみ配置
- SSH・Neovimは移行対象外。秘密鍵は引き続きBitwarden SSH agent管理

### システム設定 (`darwin/defaults.nix`)
- Dock: autohide=off, mineffect=genie, tilesize=60, mru-spaces=off, show-recents=off
- Finder: AppleShowAllExtensions=true, FXPreferredViewStyle="icnv"
- WindowManager (Stage Manager): GloballyEnabled=false (無効化済み)
- トラックパッド: Clicking=off, ThreeFingerDrag=off, RightClick=on
- 時計: ShowAMPM=true, ShowDate=0 (when space allows), ShowDayOfWeek=true
- 外観: AppleInterfaceStyle=Dark, reduceTransparency=on, increaseContrast=on
- Screencapture: style=window, 保存先 ~/Pictures/Screenshots
- NSGlobalDomain: AppleSpacesSwitchOnActivate=true 等
- それ以外 (Multitouch ジェスチャ等) は `CustomUserPreferences` で plist 直書き

---

## 5. chezmoi の使い方

SSH・Neovimのみ従来の管理を残しています。SSHの実ファイルにはchezmoiソースと
異なるローカル設定があるため、対象を指定せずに `chezmoi apply` を実行すると
その差分が失われる可能性があります。Neovim更新は対象を限定します。

```bash
chezmoi apply ~/.config/nvim
```

### Home Managerへの切り替え

移行済みのファイルは、chezmoiソースの `.chezmoiignore` に以下を追記して
二重管理を避けます。新マシンでも古いchezmoiリポジトリを利用するときは必要です。

```text
.gitconfig
.tmux.conf
.latexmkrc
.config/ghostty
```

既存の通常ファイルは初回switch時に退避します。macOSは既存設定の `.hmbak` を使い、
standalone Home Managerでは `home-manager switch -b hmbak --flake ~/nix-config#default --impure`
を使います。同名のバックアップがある場合は先に内容を確認して別名へ退避してください。
新規ファイルをGitのflakeから参照するには、適用前に `git add home` で追跡対象にします。

設定は `home/dotfiles/` を編集してswitchします。Nixが配置するファイルは通常読み取り専用です。

SSH秘密鍵はBitwarden、APIキー等はNix管理外のローカルファイルで管理します。

### Neovimの外部リポジトリ

`.chezmoiexternal.toml` は変更しません。`~/.config/nvim` のリポジトリと
未コミットの `lazy-lock.json` もそのまま残します。

---

## 6. 移行履歴

### Before (移行前)

```
~/dotfiles/                          # GNU Stow 用
├── homebrew/.Brewfile               # 36 brews + 14 casks + 27 vscode拡張
├── zsh/.zshrc                       # → stow で ~/.zshrc にシンボリックリンク
├── git/.gitconfig
├── tmux/.tmux.conf
├── latexmk/.latexmkrc
├── vscode/.vscode/                  # argv.json + extensions/
├── config/.config/                  # cagent, ghostty, gtk-3.0, nvim(submodule), uv, rstudio
└── emacs/.emacs.d/                  # submodule (tori-emacs-settings)
```

`stow -t ~ <pkg>` で全ファイルをホームへシンボリックリンクしていた。

### After (移行後)

```
~/nix-config/         # システム + パッケージ宣言
~/.local/share/chezmoi/  # dotfile 宣言
~/.config/nvim/       # tori-NV-settings 直 clone (chezmoi external)
```

> 移行直後は `~/.emacs.d/` (chezmoi external) と `~/dotfiles/` (旧 Stow アーカイブ) も
> あったが、Emacs は運用をやめ、旧アーカイブも削除済み。
> また移行後の整理で、シェル設定 (`.zshrc` 等) は chezmoi から home-manager の
> `programs.*` へさらに移した (「4. 何をどこで管理しているか」参照)。

### 主要な変更点

| 項目 | Before | After |
|---|---|---|
| パッケージ管理 | Brewfile + brew bundle | `home/default.nix` (Nix) + `darwin/homebrew.nix` (Cask中心) |
| dotfile 配置 | GNU Stow (シンボリックリンク) | chezmoi (実ファイル + テンプレート) |
| シークレット管理 | なし | Bitwarden (SSH agent 含む)。chezmoi の age 暗号化は一時使用後オフ |
| 新マシン復元 | 手動 (brew install + stow) | `nix run nix-darwin -- switch` + `chezmoi init --apply` |
| システム設定 | 手動 `defaults write` | `darwin/defaults.nix` |
| VSCode設定 | GUIで設定 | `programs.vscode` で宣言 (`mutableExtensionsDir=true`) |
| Stage Manager | OFF (デフォルト) | ON (`WindowManager.GloballyEnabled=true`) |

### Phase 別の作業履歴

1. **Phase 0**: 現状記録 (`~/nix-migration/` にbrew/dotfile/defaults をスナップショット + git init)
2. **Phase 1**: Nix基盤 (flake.nix + 最小 darwin/home → 初回 `darwin-rebuild switch`)
3. **Phase 2**: CLI 25個を `home.packages` へ追加
4. **Phase 3**: chezmoi 導入、Stow解除、age鍵生成 → Keychainバックアップ、`.chezmoiexternal.toml` で nvim/emacs 別管理
5. **Phase 4**: `darwin/homebrew.nix` で Cask宣言、`programs.vscode` + `nix-vscode-extensions` で拡張管理
6. **Phase 5**: `system.defaults` でシステム設定をNix化、Stage Manager 有効化
7. **Phase 6**: nvim/emacs 用 LSP/formatter を Nix で提供、NvChad の Mason 無効化

---

## 7. 新マシンセットアップ手順

秘密情報 (SSH 鍵) は Bitwarden にあるため、旧マシンでの事前準備は不要。Bitwarden アカウントにログインできることだけ確認しておく。

### macOS (nix-darwin): Phase 0〜8

```bash
# 0. macOS 初期セットアップ (Apple ID サインイン等は手動)

# 1. Xcode CLT
xcode-select --install

# 2. Nix インストール
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
# → 新しいターミナルを開く

# 3. SSH 鍵を Bitwarden から復元
#    Bitwarden デスクトップアプリを手動インストール (後で darwin-rebuild すると
#    cask 管理に整合される) → ログイン → 設定から SSH agent を有効化。
#    シェルで SSH_AUTH_SOCK を Bitwarden のソケットに向ける (rebuild 後は
#    darwin/bitwarden.nix が恒久設定する):
export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
ssh-add -l   # Bitwarden 内の鍵が見えればOK

# 4. nix-config を取得
git clone git@github.com:<your-account>/nix-config.git ~/nix-config
cd ~/nix-config

# 4a. 個人情報ファイルを作成 (テンプレートをコピーして編集)
cp private/user.nix.example private/user.nix
$EDITOR private/user.nix
# → username (whoami の出力) / hostname (scutil --get LocalHostName) /
#    system (Apple Silicon は "aarch64-darwin") を自分の環境に合わせる

# 4b. Nix から見えるように intent-to-add し、誤コミット防止に skip-worktree も設定
git add -N -f private/user.nix
git update-index --skip-worktree private/user.nix
# → これで Nix flake からは見えるが、git status / VSCode の git client には表示されない

# 4c. 適用 (default ホストを使うと hostname を意識しなくて済む。--impure 必須)
sudo nix run nix-darwin -- switch --flake ".#default" --impure

# 5. chezmoi 初期化 (Neovim用。SSH設定は別途確認)
chezmoi init git@github.com:tori3-po4/chezmoi-dotfiles.git
# 第5節の除外設定を追加してから、必要なNeovim設定だけを配置
chezmoi apply ~/.config/nvim
# → SSH 鍵 (Bitwarden agent) で clone → ホームに展開 → external の nvim 設定も clone

# 6. シェル再読込
exec zsh

# 7. Neovim 初回起動 (lazy.nvim 自動セットアップ)
nvim
:Lazy restore   # lazy-lock.json から復元
:q

# 8. App Store サインイン、プライバシー権限許可など (手動)
#    Zed 内蔵ターミナルから Nix を操作するため、次の権限を必ず有効にする:
#    システム設定 → プライバシーとセキュリティ → アプリ管理 → Zed
#    設定後は Zed を完全終了して起動し直す
```

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
$EDITOR private/user.nix
# username: whoami と一致
# hostname: hostnamectl --static と一致
# system: uname -m=x86_64 なら "x86_64-linux"、aarch64 なら "aarch64-linux"

# 6. private/user.nix を flake から参照可能にし、誤コミットを防止
git add -N -f private/user.nix
git update-index --skip-worktree private/user.nix

# 7. 初回ビルドと適用
#    -b hmbak は既存の競合ファイルを *.hmbak へ一度だけ退避する
nix run home-manager/master -- switch \
  --flake ".#default" --impure -b hmbak

# 8. ログインシェルを再読み込みし、導入結果を確認
exec "$SHELL" -l
home-manager generations
flatpak list --user
systemctl --user list-timers '*flatpak*'

# 9. chezmoi を初期化 (必要な場合)
chezmoi init git@github.com:tori3-po4/chezmoi-dotfiles.git
# 第5節の除外設定を追加してから、必要なNeovim設定だけを配置
chezmoi apply ~/.config/nvim
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
sandbox override、週次更新 timer は `linux/flatpak.nix` が管理する。

#### Nix 版 GUI の GPU 連携（Mesa / NVIDIA）

Fedora のカーネル側 GPU ドライバーは OS 側で管理する。Nix 版 GUI が使う
描画ライブラリは Home Manager の GPU 連携で用意する。この設定は Fedora の
ドライバーをインストール・置換するものではない。

VS Code・Emacs を Nix 管理するため、既存の GPU 連携設定は維持する。
Ghostty は macOS 限定となり、Linux 側の Ghostty 用サービス登録は不要。
Flatpak に移したアプリの描画ライブラリは Flatpak 側で管理される。

**Mesa を使う場合（nouveau など）**

`linux/default.nix` の設定本体（`imports` と同じ階層）へ追加する。

```nix
targets.genericLinux.enable = true;
targets.genericLinux.gpu.enable = true;
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
動くことを確認する。上の Mesa 用設定を、次の設定に置き換える。
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

**設定の根拠・一次資料**

まず [Home Manager 公式マニュアル：GPU on non-NixOS systems](https://nix-community.github.io/home-manager/usage/gpu-non-nixos.html) を参照する。
「When sudo is available: fixing the host OS」に GPU 連携の有効化と
`non-nixos-gpu-setup` の手順、「Nvidia drivers」にバージョン・ハッシュの取得と
`targets.genericLinux.gpu.nvidia` の設定例、OS 側とのバージョン一致条件が記載されている。
以下の実装リンクは、使用中の固定バージョンとの照合用。

本リポジトリの `flake.lock` が固定する Home Manager revision は
`3c3ede6ad886a6d9b0938ef19112523118fe62c2`。そのローカルソースで以下の実装を確認した。
リンクは同じ revision に固定しているため、将来の master の変更と区別できる。

- [GPU オプションと適用時の案内](https://github.com/nix-community/home-manager/blob/3c3ede6ad886a6d9b0938ef19112523118fe62c2/modules/targets/generic-linux/gpu/default.nix)：`gpu.enable`、NVIDIA のバージョン一致条件、ハッシュ取得例、セットアップの必要条件。
- [GPU ライブラリ構成](https://github.com/nix-community/home-manager/blob/3c3ede6ad886a6d9b0938ef19112523118fe62c2/modules/targets/generic-linux/gpu/gpu-libs-env.nix)：Mesa / libglvnd と、NVIDIA 有効時に追加するライブラリ。
- [セットアップスクリプト](https://github.com/nix-community/home-manager/blob/3c3ede6ad886a6d9b0938ef19112523118fe62c2/modules/targets/generic-linux/gpu/setup/non-nixos-gpu-setup)と [tmpfiles 設定](https://github.com/nix-community/home-manager/blob/3c3ede6ad886a6d9b0938ef19112523118fe62c2/modules/targets/generic-linux/gpu/setup/non-nixos-gpu.conf)：管理者権限が必要な変更と `/run/opengl-driver` の生成。
- [Ghostty 公式：GTK OpenGL Context Errors](https://ghostty.org/docs/help/gtk-opengl-context)：GTK / OpenGL の初期化失敗と、ライブラリ・ドライバーの不整合についての説明。Home Manager の具体的な設定の出典は上記モジュール。

### Firefox の設定と拡張機能を別マシンへ移行

この構成ではFirefoxプロファイル全体をコピーしない。宣言済みの設定は `home/firefox.nix` から再生成し、SpeedUpperはリポジトリ内のMozilla署名済みXPIから復元する。Zotero Connectorは新しいマシンでZotero公式サイトから手動導入し、それ以外のFirefox設定と拡張機能はFirefox Syncで復元する。Cookie、保存済みログイン、ログイン状態、履歴、セッション、サイトストレージは移行対象外とする。

| 移行対象 | 移行方法 |
|---|---|
| `about:config`、UI、ツールバー、キャッシュ等 | `home/firefox.nix` → Home Managerの `user.js` |
| プロファイルパス | Home Manager → macOSは `Profiles/default`、Linuxは `~/.mozilla/firefox/default` |
| `home/firefox.nix` にないFirefox設定 | Firefox Syncの「設定」を同期 |
| Zotero Connector | 新しいマシンでZotero公式サイトから手動導入 |
| SpeedUpper | `home/firefox-extensions/` の署名済みXPI → Home Manager |
| その他の拡張機能 | Firefox Syncの「アドオン」を同期 |
| 拡張機能固有の設定 | 拡張機能自身の同期機能またはエクスポート／インポート |
| Cookie、保存済みログイン、履歴、セッション等 | 移行しない |

#### 1. 移行元のMacで準備

1. `home/firefox.nix` と `home/firefox-extensions/` を含む最新のNix設定をコミットしてリモートへpushする。
2. Firefoxの「設定 → Sync → 同期する項目を変更」で **アドオンと設定だけ** を有効にする。パスワード、履歴、開いているタブ、ブックマーク、住所、支払い方法等は無効にする。同期対象の変更方法は[Mozilla公式ヘルプ](https://support.mozilla.org/en-US/kb/how-do-i-choose-what-information-sync-firefox)を参照。
3. 拡張機能固有の設定が必要なら、それぞれの拡張機能が提供する同期機能を有効にするか、設定をエクスポートする。Firefox Syncで拡張機能本体が復元されても、拡張機能内部のデータまで必ず同期されるとは限らない。

現在有効なユーザ導入拡張機能は、移行確認用に次のコマンドで一覧を保存できる。

```bash
firefox_extensions="$HOME/Library/Application Support/Firefox/Profiles/default/extensions.json"

jq -r '
  .addons[]
  | select(.type == "extension" and .active == true and .location == "app-profile")
  | [(.defaultLocale.name // .id), .id]
  | @tsv
' "$firefox_extensions" > "$HOME/Desktop/firefox-extensions.tsv"
```

#### 2. 新しいmacOSで復元

1. 前節のPhase 4cを実行する。Homebrew版Firefoxが導入され、共通パス `Profiles/default` の `profiles.ini` と `user.js` に加えてSpeedUpperの署名済みXPIがHome Managerから配置される。
2. `/Applications/Firefox.app` を起動する。
3. 旧 Macと同じFirefoxアカウントへログインし、Syncは **アドオンと設定だけ** を有効にする。`home/firefox.nix` と重複する設定は、次回起動時にHome Managerの `user.js` の値が優先される。
4. Zotero公式サイトからZotero Connectorを導入し、Zoteroとの接続を確認する。
5. `firefox-extensions.tsv` と「アドオンとテーマ」の一覧を比較し、SpeedUpper以外で不足している拡張機能を手動で導入する。
6. 旧 Macでエクスポートした拡張機能固有の設定があればインポートする。各サービスや拡張機能へのログインは新 Macでやり直す。

復元後に次を確認する。

- `about:config` の設定、UI、ツールバー配置が `home/firefox.nix` の内容になっている。
- 必要な拡張機能が有効になっている。
- DRMコンテンツを使う場合は「設定 → 一般 → DRMコンテンツを再生」とWidevineが有効になっている。

> `~/Library/Application Support/Firefox` は旧 Macからコピーしない。これによりCookie、ログイン状態、保存済みログイン、履歴、セッション、サイトストレージ等を新 Macへ持ち込まない。`profiles.ini`、`Profiles/default`、`user.js`を含む宣言部分はHome Managerが再生成する。

#### 3. 新しいLinux（Flatpak）で復元

1. [Fedora など dnf 系 Linux](#fedora-など-dnf-系-linux-standalone-home-manager) の手順でFlatpak本体、desktop portal、Nix、Home Manager構成を導入する。Flathub remote、ユーザ用アプリ、overrideは `nix-flatpak` が管理するため、個別の `flatpak install` / `flatpak override` は実行しない。
2. `private/user.nix` の `system` がLinuxのCPUに合う `x86_64-linux` または `aarch64-linux` であることを確認する。`flake.nix` はその値から `homeConfigurations.default` と `homeConfigurations."<user>@<host>"` を生成する。
3. FirefoxとZedを終了してから対象のHome Manager構成を適用する。

   ```bash
   home-manager switch --flake ~/nix-config#default --impure
   ```

4. `flatpak run org.mozilla.firefox` で起動する。Firefoxアカウントへログインし、Zotero ConnectorはZotero公式サイトから手動導入する。

LinuxではHome ManagerのFirefoxモジュールが通常のFirefoxと同じ場所を管理し、SpeedUpperも `profiles.default.extensions.packages` で配置する。

```text
~/.mozilla/firefox/profiles.ini
~/.mozilla/firefox/default/user.js
~/.mozilla/firefox/default/extensions/speedupper@local.xpi
```

Home Managerの管理ファイルは `/nix/store` へのシンボリックリンクになるため、`linux/flatpak.nix` がFirefoxの標準プロファイルへ読み書き、Nix storeへ読み取り専用の権限を与える。ZedはFlatpak内の `XDG_CONFIG_HOME` をHome Managerの `~/.config` へ揃える。Home Manager自身は `~/.var/app` 以下を直接管理せず、Cookie、ログイン状態、履歴、拡張機能内部データなどの可変状態はFlatpak側に残す。

#### Firefoxが「Your profile cannot be loaded」で起動しない場合

`--profile "$HOME/.mozilla/firefox/default"` を付けると起動できる場合、通常起動時のプロファイル選択を確認する。Firefoxは `profiles.ini` の `[Install<インストールID>]` でインストールごとの起動先を選ぶ。`installs.ini` はバックアップ用なので、こちらだけの変更では直らないことがある。

`linux/flatpak.nix` はFedora実機で確認したFlathub版のID `CF146F38BCAB2D21` に対して `Default=default` を宣言する。Firefoxを終了してから `home-manager switch --flake ~/nix-config#default --impure` で反映し、`flatpak run org.mozilla.firefox` で通常起動を確認する。異なる配布元・インストール先ではIDが異なる可能性があるため、このIDをそのまま流用しない。

仕様: [Mozilla Profiles Service Changes](https://firefox-source-docs.mozilla.org/toolkit/profile/changes.html#profile-per-install)。既存のプロファイルフォルダを削除する必要はない。

### 鍵が使えない場合のフォールバック

- **Bitwarden にログインできない**: SSH 鍵が取り出せない。新規 SSH 鍵を生成して GitHub の公開鍵を差し替える。

---

## 8. トラブルシュート

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

Zed 内蔵ターミナルから実行した Nix の GC が、古い `.app` を削除するための「アプリ管理」権限を macOS に拒否されている。
「システム設定 → プライバシーとセキュリティ → アプリ管理」で **Zed** を許可し、Zed を完全終了して起動し直してから GC を再実行する。

#### `vscode-extension-* removed on aarch64-darwin`
`ms-vscode.cpptools` 等の proprietary 拡張は `nix-vscode-extensions` 側で darwin から除外される。
本リポジトリでは nixpkgs 同梱の `pkgs.vscode-extensions.ms-vscode.cpptools` (unfree) で代替している (`home/vscode.nix` 参照)。`mutableExtensionsDir = false` なので GUI からの追加は反映されない — 拡張は必ず `vscode.nix` に書く。

#### `attribute 'foo' missing` / `option does not exist`
nix-darwin が知らないオプション名を `system.defaults.*` に書いた。
[MyNixOS](https://mynixos.com/) で正しい名前を検索するか、`CustomUserPreferences` に逃がす。

### `nix flake update` 後にビルドが壊れた

nixpkgs-unstable を追従している以上、上流のツールチェーン更新でパッケージが壊れることがある。切り分けと対処:

```bash
# 1. まず switch せずビルドだけして原因パッケージを特定
nix build .#darwinConfigurations.default.system --impure --no-link --keep-going 2>&1 | grep "Cannot build"

# 2. 上流で既知/修正済みか確認 (Hydra のジョブ状況、nixpkgs の issue)
#    https://hydra.nixos.org/job/nixpkgs/trunk/<pkg>.aarch64-darwin/latest

# 3. 上流修正待ちの間は、壊れたパッケージだけ旧 nixpkgs リビジョンにピン留めする
```

ピン留めの手順 (espanso での実例が `flake.nix` にある):

1. `flake.nix` の inputs に旧リビジョンを追加: `nixpkgs-<pkg>.url = "github:NixOS/nixpkgs/<動いていた rev>";`
2. overlay で該当パッケージだけ差し替え: `<pkg> = inputs.nixpkgs-<pkg>.legacyPackages.${prev.stdenv.hostPlatform.system}.<pkg>;`
3. `nix flake lock` で lock に反映 → ビルド確認
4. **上流で直ったら input と overlay を削除する** (ピン留めしたままだと古いバイナリが残り続ける)

#### 実例: espanso (2026-07 適用中)

2026-07 の update で nixpkgs が LLVM/clang 21 系に移行した際、espanso 2.3.0 が
aarch64-darwin のリンク段階で失敗するようになった (`clang: linker command failed
with exit code 133`)。上流未修正のため、ビルドが通っていたリビジョンを
`nixpkgs-espanso` input としてピン留めし、`espansoPinOverlay` で espanso だけ
そこから取得している。上流で修正が入ったら両方を削除すること。

### `private/user.nix` 関連

#### `Path 'private/user.nix' in the repository ... is not tracked by Git`
flake は git 追跡内のファイルしか参照できない。intent-to-add すれば内容を漏らさず可視化できる:
```bash
git add -N -f private/user.nix
```

#### `private/user.nix` が VSCode の Source Control に出てくる / 誤コミットしてしまう
intent-to-add 状態だと VSCode の git client に拾われるので、`skip-worktree` で完全に隠す:
```bash
git update-index --skip-worktree private/user.nix
# 解除したいとき:
git update-index --no-skip-worktree private/user.nix
```

#### 誤って `private/user.nix` を内容ごとコミットしてしまった
直前のコミットなら amend で消す:
```bash
git rm --cached private/user.nix
git commit --amend --no-edit
git push --force-with-lease origin main   # push 済みなら
git add -N -f private/user.nix             # intent-to-add 復元
git update-index --skip-worktree private/user.nix
```
過去の複数コミットに含まれている場合は `git filter-repo --replace-text` で全履歴から除去 →`git push --force` する。

### chezmoi の trouble

#### `chezmoi managed` でファイルが見えない
```bash
chezmoi cd
ls -la
git ls-files
```

### システム defaults が反映されない
```bash
killall Dock; killall Finder; killall cfprefsd
# または再ログイン
```

### nvim が起動しない / 設定が壊れた
chezmoi external の clone 失敗の可能性:
```bash
chezmoi apply -v   # 詳細ログで状況確認
# 必要なら ~/.config/nvim を rm -rf して chezmoi apply で再 clone
```

---

## 9. 今後の TODO / 既知の制限

- **espanso のピン留め解除**: nixpkgs の LLVM/clang 21 移行で espanso が darwin でビルド不能 (2026-07 時点)。`nixpkgs-espanso` input + `espansoPinOverlay` で旧リビジョンにピン留め中。上流修正後に削除する (「8. トラブルシュート」参照)
- **jetbrains-wrapper-fix.nix の上流化**: JetBrains CLI ランチャーの日本語 CWD 問題は overlay で対処中。nixpkgs に PR を出して不要にする (ファイル内 TODO 参照)
- **homebrew cleanup**: 現状 `cleanup = "uninstall"`。安定運用が続けば `"zap"` へ引き上げ検討
- **direnv 連携**: パッケージとして direnv は入れているが `programs.direnv` (nix-direnv 統合) は未設定
- **Nix で管理できないもの**: TCC (プライバシー権限)、App Store サインイン、Bitwarden ログイン等は新マシンで手動

---

## 参考リンク

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [home-manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager: standalone flake setup](https://nix-community.github.io/home-manager/nix-flakes/standalone.html)
- [NixOS/nix-installer](https://github.com/NixOS/nix-installer)
- [Fedora Packages: nix](https://packages.fedoraproject.org/pkgs/nix/nix/)
- [Fedora: Nix package tool](https://fedoraproject.org/wiki/Changes/Nix_package_tool)
- [nix-flatpak](https://github.com/gmodena/nix-flatpak)
- [chezmoi docs](https://www.chezmoi.io/)
- [nix-vscode-extensions](https://github.com/nix-community/nix-vscode-extensions)
- [MyNixOS (オプション横断検索)](https://mynixos.com/)
- 移行プロセス全体ガイド: [`nix-macos-guide.md`](./nix-macos-guide.md) (リポジトリ直下)
- Sunshine + Moonlight: [`sunshine-moonlight.md`](./sunshine-moonlight.md)
