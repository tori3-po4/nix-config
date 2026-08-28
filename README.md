# nix-config — macOS / Linux 環境の宣言的管理

このリポジトリは、macOS では [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager)、Fedora など dnf 系 Linux では standalone Home Manager を使って環境を宣言的に管理するためのものです。dotfile (シェル設定等) は別リポジトリ [chezmoi-dotfiles](https://github.com/tori3-po4/chezmoi-dotfiles) で [chezmoi](https://www.chezmoi.io/) により管理しています。

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
│  - home.packages       │ CLI、LSP、VSCode/JetBrains/Ghostty本体 │
│  - programs.*          │ zsh/bash/starship/fzf/zoxide/firefox/  │
│                        │ espanso/emacs/vscode/zed (拡張 + 設定) │
├────────────────────────┼───────────────────────────────────────┤
│ nix-flatpak (Linux)    │ GUIアプリ本体 + sandbox設定           │
│  - packages            │ Firefox/Zed/Chrome/Anki等             │
│  - overrides           │ Home Manager設定へのアクセス権限      │
├────────────────────────┼───────────────────────────────────────┤
│ chezmoi                │ dotfile (試行錯誤するもの)             │
│  - dot_gitconfig 等    │ git / tmux / latexmk                   │
│  - dot_ssh             │ SSH config のみ (鍵は Bitwarden 管理)  │
│  - dot_config/*        │ ghostty, cagent, gtk-3.0               │
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
├── image-build.md       # Docker / qcow2 image のビルド手順
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
│   ├── linux-builder.nix # macOS から Linux image を作る builder VM
│   ├── bitwarden.nix    # Bitwarden SSH agent を SSH_AUTH_SOCK に設定
│   └── jetbrains-wrapper-fix.nix  # JetBrains CLI ランチャーの日本語CWD問題対策 overlay
├── linux/               # Linuxユーザ環境固有の宣言
│   ├── default.nix      # linux/* を importするエントリポイント
│   └── flatpak.nix      # Flatpakアプリ、更新方針、sandbox override
├── images/              # Linux image の宣言
│   ├── docker.nix       # Docker load 用 nix-hello image
│   └── vm.nix           # systemd-repart ベースの NixOS VM image
└── home/                # home-manager (yourname 用)
    ├── default.nix      # home.packages 一覧 + 各モジュール import
    ├── emacs.nix        # macOS/Linux Emacs 31.1 + 共通 init.el
    ├── emacs/init.el    # GNU/NonGNU ELPA、Evil(devel)/Corfu/Magit等の設定
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
- **`home/default.nix`**: 全てのCLIツール (ripgrep, jq, bat, eza, git, neovim, LSP一式, formatter等) と Nix管理するGUI本体 (VSCode, JetBrains IDE, Ghostty, LM Studio)。Firefox/Zed本体はプラットフォーム側で管理。
- **`home/emacs.nix` / `home/emacs/init.el`**: GNU公式tarballのURLとSHA-256で厳密固定したmacOS/Linux共通 Emacs 31.1 no-X/TUI設定。nixpkgsはビルド定義と依存関係にのみ使い、`emacs-overlay`には依存しない。Native Compilation、Tree-sitter、TUI child frameを有効にする。EvilだけはCorfu互換修正を取り込むためNonGNU-develに固定し、Corfu/Magit/SLIME/nix-modeはGNU/NonGNU ELPAの安定版、Eglot/TRAMP/which-keyはEmacs 31.1同梱版を使う。
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

### Docker / qcow2 image

macOS では nix-darwin の Linux builder を介し、Linux binary だけを含む image を
生成します。初回設定、アーキテクチャ別コマンド、image のカスタマイズ方法は
[image-build.md](./image-build.md) を参照してください。

### chezmoi 側

```bash
# 既存ファイルを取り込み (新規追加時)
chezmoi add ~/.zshrc

# 編集 (chezmoi のソースを vim/emacs で開く)
chezmoi edit ~/.zshrc

# プレビュー
chezmoi diff

# 適用
chezmoi apply

# ソースリポジトリへ移動
chezmoi cd
git status
git push
exit
```

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
- エディタ/GUI本体: neovim, vscode, jetbrains (pycharm/clion/idea), ghostty-bin
- シェル支援: tmux, zellij, direnv, stow, chezmoi
- ローカルLLM: llama-cpp (UI無効 overlay), lmstudio
- 暗号/パスワード: gnupg, age, bitwarden-cli
- 言語処理系: deno, nodejs_22, uv, pixi, SBCL, jdk, gradle
- ビルド: automake, cmake, meson, pkgconf, gnumake, gcc, lld, lldb, llvm, openmp
- 画像/動画/PDF: ffmpeg, imagemagick, libwebp, poppler, yt-dlp, pandoc
- コンテナ: docker-client, docker-compose (daemon は Docker Desktop cask)
- LaTeX: texlive (scheme-full), ghostscript, tex-fmt
- LSP: lua-language-server, nil, nixd, pyright, rust-analyzer, typescript-language-server, texlab, clang-tools, marksman, yaml-language-server, bash-language-server, vscode-langservers-extracted
- Formatter/Linter: stylua, nixfmt, ruff, rustfmt, prettier, shellcheck, shfmt
- programs.* 設定: zsh, bash, starship, fzf, zoxide, emacs, firefox (user.js), vscode, zed-editor, espanso

### Homebrew (`darwin/homebrew.nix`)
- **Casks**: anki, bitwarden, blender, chatgpt, claude-code@latest, codex, discord, docker-desktop, firefox, font-hackgen-nerd, google-chrome, latexit, llama-app, logi-options+, minecraft, multipass, pearcleaner, skim, slack, tailscale-app, wireshark-app, zed, zotero
- **Taps**: なし
- **Brews**: mole (gtkwave は必要になったら `randomplum/gtkwave` tap で復活させる)
- 運用: `cleanup = "uninstall"` / `autoUpdate` / `upgrade` / `greedyCasks` すべて有効

### Emacs 31.1

- macOS/Linux: GNU公式 `emacs-31.1.tar.xz` をURLとSHA-256で厳密に固定し、nixpkgsの `emacs31-nox` ビルド定義でコンパイルする。`emacs-overlay` は使わない。
- Native Compilation と Tree-sitter を有効にし、フルAOTのみ無効化。no-X版のためGUI依存を持たず、TUIで共通利用する。
- 共通設定: `~/.config/emacs/init.el` と互換用 `~/.emacs.d/init.el`。GNU ELPA / NonGNU ELPA の安定版を基本とし、Evil だけを NonGNU-devel に固定。不足パッケージと Evil の devel 更新を起動時に自動導入する。
- ELPA本体とquickstartはEmacsメジャー別に保存し、32で生成したbyte-codeを31から読まない。
- TUI: Emacs 31標準の tty child frame をCorfu 2.xが自動検出するため `corfu-terminal` は不要。
- Zellij: locked mode を既定とし、`F12` 以外のキー入力を Emacs に通す。`F12` で Zellij の normal/locked mode を切り替える。

確認用:

```bash
emacs --version
emacs --batch --eval '(princ (native-comp-available-p))'
emacs --batch --eval "(princ (featurep 'tty-child-frames))"
```

### Flatpak (`linux/flatpak.nix`)

- **全アーキテクチャ**: Anki, Bitwarden, Google Chrome, Firefox, Zed, Zotero
- **x86_64のみ**: Blender, Discord, Slack
- `uninstallUnmanaged = true` により、ユーザ単位で導入した宣言外Flatpakを削除
- activation時更新は無効。アプリ更新は週次のsystemd user timerで実行
- Firefox/Zedはoverrideを通じて `home/firefox.nix` / `home/zed.nix` の設定を利用
- WiresharkはFlathub版にパケットキャプチャ機能がないため対象外

### chezmoi (`~/.local/share/chezmoi/`)
- `dot_gitconfig`, `dot_tmux.conf`, `dot_latexmkrc`
- `dot_config/{cagent,ghostty,private_gtk-3.0}/`
- `dot_vscode/argv.json`
- `dot_ssh/config`: SSH config のみ (秘密鍵は Bitwarden SSH agent 管理。`darwin/bitwarden.nix` 参照)
- `.chezmoiexternal.toml`: `.config/nvim` を別リポジトリから clone
- ※ age 暗号化はオフ (シークレットは Bitwarden / ローカルファイルで管理)
- ※ シェル設定 (`.zshrc` 等) は home-manager の `programs.zsh/bash` に移行済み

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

### 基本概念

- **Source dir** (`~/.local/share/chezmoi/`): chezmoi が管理するファイルの「ひな形」を置く場所。git管理。
- **Target dir** (`~/`): 実際にファイルを配置する場所 (=ホームディレクトリ)。
- **接頭辞**: `dot_` → `.` に変換。`private_` → 権限 600。`encrypted_` → 暗号化。`empty_` → 空ファイル可。
- **テンプレート**: `*.tmpl` 拡張子。Goテンプレート構文でマシン別差分を吸収。

### シークレットの扱い

chezmoi の age 暗号化は**現在オフ**にしている。秘密情報は chezmoi に置かず、以下で管理する:

- **SSH 秘密鍵**: Bitwarden の SSH agent (`darwin/bitwarden.nix` で `SSH_AUTH_SOCK` を Bitwarden に向けている)。chezmoi 管理は `~/.ssh/config` のみ。
- **API キー等**: Nix / chezmoi 管理外の通常ファイルとしてローカルに置く。

### 既存ファイルを取り込む

```bash
chezmoi add ~/.gitconfig                  # 通常
chezmoi chattr +template ~/.gitconfig     # テンプレート化
```

### 編集 → 反映 → push

```bash
chezmoi edit ~/.zshrc       # source dir の dot_zshrc を $EDITOR で開く
chezmoi diff                # 何が変わるか確認
chezmoi apply               # ホームへ反映 (既存ファイルは自動 backup)
chezmoi cd                  # source dir へ移動
git add . && git commit -m "..." && git push
exit
```

### .chezmoiexternal.toml

`~/.config/nvim/` は別リポジトリで管理しているため、chezmoi では「外部リポジトリ参照」として宣言:

```toml
[".config/nvim"]
    type = "git-repo"
    url = "git@github.com:tori3-po4/tori-NV-settings.git"
    refreshPeriod = "168h"
```

`chezmoi apply` 時に未存在なら clone、`refreshPeriod` 経過時は pull。

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

# 5. chezmoi 初期化 (dotfile 一式 + nvim 設定を一発展開)
chezmoi init --apply git@github.com:tori3-po4/chezmoi-dotfiles.git
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
chezmoi init --apply git@github.com:tori3-po4/chezmoi-dotfiles.git
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
