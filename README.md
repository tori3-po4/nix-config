# nix-config — macOS 環境の宣言的管理

このリポジトリは [nix-darwin](https://github.com/nix-darwin/nix-darwin) + [home-manager](https://github.com/nix-community/home-manager) を使って macOS の設定を宣言的に管理するためのものです。dotfile (シェル設定等) は別リポジトリ [chezmoi-dotfiles](https://github.com/tori3-po4/chezmoi-dotfiles) で [chezmoi](https://www.chezmoi.io/) により管理しています。

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
│ Nix (nix-darwin)       │ システム設定 + Homebrew統合            │
│  - system.defaults     │ Dock/Finder/トラックパッド/Stage Mgr   │
│  - homebrew.casks      │ GUIアプリ                              │
│  - homebrew.brews      │ macOS toolchain系のみ残し               │
├────────────────────────┼───────────────────────────────────────┤
│ Nix (home-manager)     │ パッケージとツールチェーン             │
│  - home.packages       │ CLIツール、LSP、フォーマッタ           │
│  - programs.vscode     │ VSCode拡張 + settings.json             │
├────────────────────────┼───────────────────────────────────────┤
│ chezmoi                │ dotfile (試行錯誤するもの)             │
│  - dot_zshrc 等        │ シェル / git / tmux / latex            │
│  - dot_config/*        │ ghostty, cagent, gtk-3.0 等            │
│  - .chezmoiexternal    │ NvChad, Emacs 設定 (別リポジトリ)      │
├────────────────────────┼───────────────────────────────────────┤
│ Homebrew (Cask中心)    │ Sparkle更新が必要なGUIアプリ           │
│  - VSCode本体は手動    │ Cask管理外、自動更新                   │
│  - opam (OCaml)        │ ocaml-lsp 等は opam switch ごと        │
└────────────────────────┴───────────────────────────────────────┘
```

### Git リポジトリ

| 用途 | 場所 | リモート |
|---|---|---|
| Nix 設定 | `~/nix-config/` | (private) |
| dotfile | `~/.local/share/chezmoi/` | `git@github.com:tori3-po4/chezmoi-dotfiles.git` |
| Neovim 設定 | `~/.config/nvim/` (chezmoi external) | `git@github.com:tori3-po4/tori-NV-settings.git` |
| Emacs 設定 | `~/.emacs.d/` (chezmoi external) | `git@github.com:tori3-po4/tori-emacs-settings.git` |
| 旧 Stow リポジトリ | `~/dotfiles/` | (アーカイブ) |

---

## 2. リポジトリ構成

```
~/nix-config/
├── flake.nix            # 入力定義 (nixpkgs, nix-darwin, home-manager, nix-vscode-extensions)
├── flake.lock           # ロックファイル (Nixが管理 / sudoで触ると root 所有になる)
├── .gitignore
├── darwin/              # macOSシステム/ユーザレベル設定
│   ├── default.nix      # darwin/* を import するエントリポイント
│   ├── homebrew.nix     # cask + brew + tap 宣言
│   └── defaults.nix     # system.defaults (Dock, Finder, トラックパッド, Stage Manager 等)
└── home/                # home-manager (yourname 用)
    ├── default.nix      # home.packages 一覧 + vscode.nix import
    ├── vscode.nix       # programs.vscode (拡張 + 設定)
    └── vscode-settings.json  # VSCode の userSettings (JSON)
```

### 各ファイルの役割

- **`flake.nix`**: インプット (依存リポジトリ) と出力 `darwinConfigurations.your-host` を定義。`nix-vscode-extensions` overlay と `nixpkgs.config.allowUnfree = true` もここで設定。
- **`darwin/default.nix`**: `system.stateVersion` / `system.primaryUser` / Nixpkgs設定。`./homebrew.nix` と `./defaults.nix` を import。
- **`darwin/homebrew.nix`**: Brewfile相当の宣言。`onActivation.cleanup = "none"` で安全運用 (将来 `"uninstall"` → `"zap"` に強化)。
- **`darwin/defaults.nix`**: macOS のあらゆる `defaults write` 相当を宣言。nix-darwin が公式オプションを持たない場合は `CustomUserPreferences` で plist 直書き。
- **`home/default.nix`**: 全てのCLIツール (ripgrep, jq, bat, eza, git, neovim, LSP一式, formatter等)。
- **`home/vscode.nix`**: `programs.vscode` で 23拡張 + `userSettings`。`mutableExtensionsDir = true` なのでGUIから追加もOK。

---

## 3. 日常運用コマンド

### Nix側

```bash
# 設定変更後の反映 (sudo 必須)
sudo darwin-rebuild switch --flake ~/nix-config

# 履歴確認
sudo darwin-rebuild --list-generations

# 直前世代に戻す (壊れた時)
sudo darwin-rebuild rollback

# 入力(リポジトリ)を最新に更新
cd ~/nix-config
nix flake update

# Nix store のごみ掃除
sudo nix-collect-garbage -d
sudo darwin-rebuild switch --flake ~/nix-config  # 起動可能世代を再確定
```

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
sudo darwin-rebuild switch --flake ~/nix-config  # cleanup の強度に応じて整理
```

---

## 4. 何をどこで管理しているか

### Nix (`home/default.nix`)
- 基本CLI: ripgrep, fd, fzf, jq, bat, eza, coreutils
- Git周辺: git, git-filter-repo, lazygit, gh
- エディタ/シェル支援: neovim, tmux, zoxide, starship, direnv, stow, chezmoi
- 暗号: gnupg, age
- 言語処理系: deno, nodejs_22, uv, opam, R
- ビルド: automake, cmake, meson, pkgconf, gnumake
- 画像/動画/PDF: ffmpeg, imagemagick, libwebp, poppler
- 特殊: tree-sitter, iverilog, llama-cpp, arduino-cli
- LaTeX: texlive (scheme-full), tex-fmt
- LSP: lua-language-server, nil, pyright, rust-analyzer, typescript-language-server, texlab, clang-tools, marksman, yaml-language-server, bash-language-server, vscode-langservers-extracted
- Formatter/Linter: stylua, nixfmt-rfc-style, ruff, rustfmt, prettier, shellcheck, shfmt

### Homebrew (`darwin/homebrew.nix`)
- **Casks**: blender, claude-code, cmake-app, docker-desktop, emacs-app, font-hackgen-nerd, ghostty, obsidian, pearcleaner, raspberry-pi-imager, rstudio, skim, utm
- **Brews (macOS toolchain系のみ)**: sqlite, flyctl, gcc, libomp, llvm, gtkwave (with `randomplum/gtkwave` tap)

### chezmoi (`~/.local/share/chezmoi/`)
- `dot_zshrc`, `dot_zprofile`, `dot_zshenv` (PATH 修正含む)
- `dot_gitconfig`, `dot_tmux.conf`, `dot_latexmkrc`
- `dot_config/{cagent,ghostty,gtk-3.0}/`
- `dot_vscode/argv.json`
- `dot_ssh/encrypted_*.age`: SSH config + 鍵一式 (age 暗号化)
- `.chezmoiexternal.toml`: `.config/nvim` と `.emacs.d` を別リポジトリから clone
- `.chezmoiignore`: `.DS_Store` 除外
- 暗号化: age (`encryption = "age"`)

### システム設定 (`darwin/defaults.nix`)
- Dock: autohide=off, mineffect=genie, tilesize=60, mru-spaces=off, show-recents=off
- Finder: AppleShowAllExtensions=true, FXPreferredViewStyle="icnv"
- WindowManager (Stage Manager): GloballyEnabled=true, AppWindowGrouping=true
- トラックパッド: Clicking=off, ThreeFingerDrag=off, RightClick=on
- 時計: ShowAMPM=true, ShowDate=0 (when space allows), ShowDayOfWeek=true
- Screencapture: style=window
- NSGlobalDomain: AppleSpacesSwitchOnActivate=true 等
- それ以外は `CustomUserPreferences` で plist 直書き

---

## 5. chezmoi の使い方

### 基本概念

- **Source dir** (`~/.local/share/chezmoi/`): chezmoi が管理するファイルの「ひな形」を置く場所。git管理。
- **Target dir** (`~/`): 実際にファイルを配置する場所 (=ホームディレクトリ)。
- **接頭辞**: `dot_` → `.` に変換。`private_` → 権限 600。`encrypted_` → 暗号化。`empty_` → 空ファイル可。
- **テンプレート**: `*.tmpl` 拡張子。Goテンプレート構文でマシン別差分を吸収。

### 暗号化 (age)

- 鍵ファイル: `~/.config/chezmoi/key.txt` (chmod 600)
- 公開鍵 (recipient): `age1a7rzqkdaedfqhzktkdyvpfkxx3mkw6nkccuj7na9v45pu3hqse8s0dvj32`

#### バックアップ戦略

age 鍵は chezmoi で管理している暗号化ファイル全部 (SSH 秘密鍵を含む) を復号する**マスターキー**なので、**マシン移行 / 災害復旧で確実に復元できる**場所に置く必要がある。

| 手法 | 用途 | 同一マシン復旧 | 別マシン復旧 |
|---|---|---|---|
| age tarball + iCloud Drive | **メイン**。SSH 鍵と age 鍵を passphrase 付き age で固めて iCloud に置く | ✅ | ✅ |
| macOS Keychain | 同一マシンでファイル消失した時の予備 | ✅ | ❌ (generic password は iCloud 同期されない) |

**メイン: age tarball**

```bash
# 作成 (パスフレーズを 2 回入力)
tar czf - -C "$HOME" \
  .config/chezmoi/key.txt \
  .ssh/id_ed25519 \
  .ssh/id_ed25519.pub \
  | age -p > "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup/keys.tar.age"

# 内容確認
age -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup/keys.tar.age" | tar -tz

# 復元 (新マシン or 鍵紛失時)
age -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup/keys.tar.age" | tar xz -C "$HOME"
chmod 600 ~/.config/chezmoi/key.txt ~/.ssh/id_ed25519
```

tarball のパスフレーズを忘れると復旧不能なので、強いパスフレーズを別途記録しておく (1Password / 紙メモ + 金庫 等)。

**予備: macOS Keychain (同一マシン復旧専用)**

```bash
# 確認
security find-generic-password -s "chezmoi-age-key" -a "$USER" -w | xxd -r -p

# 復元 (同じマシンで key.txt を消してしまった等)
security find-generic-password -s "chezmoi-age-key" -a "$USER" -w | xxd -r -p > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

> Keychain の generic password は iCloud Keychain で同期されないため、**別マシンには復元不能**。あくまで同じマシン内のファイル消失対策。

### 既存ファイルを取り込む

```bash
chezmoi add ~/.gitconfig                  # 通常
chezmoi add --encrypt ~/.ssh/config       # 暗号化
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

`~/.config/nvim/` と `~/.emacs.d/` は別リポジトリで管理しているため、chezmoi では「外部リポジトリ参照」として宣言:

```toml
[".config/nvim"]
    type = "git-repo"
    url = "git@github.com:tori3-po4/tori-NV-settings.git"
    refreshPeriod = "168h"

[".emacs.d"]
    type = "git-repo"
    url = "git@github.com:tori3-po4/tori-emacs-settings.git"
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
~/.emacs.d/           # tori-emacs-settings 直 clone (chezmoi external)
~/dotfiles/           # アーカイブ (削除可だが念のため残す)
```

### 主要な変更点

| 項目 | Before | After |
|---|---|---|
| パッケージ管理 | Brewfile + brew bundle | `home/default.nix` (Nix) + `darwin/homebrew.nix` (Cask中心) |
| dotfile 配置 | GNU Stow (シンボリックリンク) | chezmoi (実ファイル + テンプレート) |
| dotfile暗号化 | なし | age (Keychainバックアップ) |
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

### Phase -1: 旧マシンでの事前準備 (移行前にやっておくこと)

新マシンには **SSH 鍵が無いと private リポジトリの clone もできない**ので、鍵束を旧マシンで暗号化バックアップしておく必要がある。

```bash
# 旧マシンで実行: keys.tar.age を iCloud Drive に作成
mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup"
tar czf - -C "$HOME" \
  .config/chezmoi/key.txt \
  .ssh/id_ed25519 \
  .ssh/id_ed25519.pub \
  | age -p > "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup/keys.tar.age"
```

- パスフレーズは強いものを設定し、別途記録しておく (忘れると復旧不能)
- iCloud Drive に置いた tarball は新マシンの Apple ID サインイン後に自動で同期される
- 詳細は「5. chezmoi の使い方 → 暗号化 (age) → バックアップ戦略」参照

### Phase 0〜8: 新マシンでの作業

```bash
# 0. macOS 初期セットアップ (Apple ID 手動 → iCloud Drive で keys.tar.age が同期される)

# 1. Xcode CLT
xcode-select --install

# 2. Nix インストール
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
# → 新しいターミナルを開く

# 3. age を最低限 nix-shell で取り出して鍵束を復元
nix-shell -p age --run '
  age -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/keys-backup/keys.tar.age" \
    | tar xz -C "$HOME"
'
chmod 700 ~/.ssh ~/.config/chezmoi
chmod 600 ~/.config/chezmoi/key.txt ~/.ssh/id_ed25519
# → ここで Phase -1 で設定した tarball のパスフレーズを 1 回入力
# → ~/.config/chezmoi/key.txt と ~/.ssh/id_ed25519{,.pub} が復元される
# → tar が自動生成する中間ディレクトリは 755 になるため、~/.ssh を 700 に直さないと SSH が鍵を拒否する

# 4. SSH 鍵を ssh-agent + Keychain に登録
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
# → ここで SSH 鍵自体のパスフレーズを 1 回入力 (以降 Keychain から自動取得)

# 5. nix-config を取得して適用
git clone git@github.com:<your-account>/nix-config.git ~/nix-config
cd ~/nix-config
sudo nix run nix-darwin -- switch --flake ".#your-host"
# → 失敗時は flake.nix の hostname / username を新マシンに合わせる

# 6. chezmoi 初期化 (dotfile 一式 + nvim/emacs を一発展開)
chezmoi init --apply git@github.com:tori3-po4/chezmoi-dotfiles.git
# → SSH 鍵で clone → age 鍵で encrypted_*.age を復号 → ホームに展開

# 7. シェル再読込
exec zsh

# 8. Neovim 初回起動 (lazy.nvim 自動セットアップ)
nvim
:Lazy restore   # lazy-lock.json から復元
:q

# 9. App Store サインイン、プライバシー権限許可など (手動)
```

### 鍵を忘れた / iCloud が使えない場合のフォールバック

- **age tarball のパスフレーズを忘れた**: 復旧不能。新規 SSH 鍵生成 → GitHub 公開鍵差し替え → 新規 age 鍵生成 → 旧 chezmoi リポジトリの暗号化ファイルは捨てて再構築。
- **iCloud Drive にアクセスできない**: 旧マシンが生きていれば AirDrop / scp で `keys.tar.age` を転送、または `~/.config/chezmoi/key.txt` と `~/.ssh/id_ed25519` を直接転送。

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

#### `vscode-extension-* removed on aarch64-darwin`
`ms-vscode.cpptools` 等の proprietary 拡張は darwin で除外される。
`vscode.nix` から外し、`mutableExtensionsDir = true` のため VSCode GUI から手動で追加可能。

#### `attribute 'foo' missing` / `option does not exist`
nix-darwin が知らないオプション名を `system.defaults.*` に書いた。
[MyNixOS](https://mynixos.com/) で正しい名前を検索するか、`CustomUserPreferences` に逃がす。

### chezmoi の trouble

#### `chezmoi managed` でファイルが見えない
```bash
chezmoi cd
ls -la
git ls-files
```

#### age 鍵を紛失した
**バックアップから復元** (Keychain の `chezmoi-age-key`):
```bash
security find-generic-password -s "chezmoi-age-key" -a "$USER" -w | xxd -r -p > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

### システム defaults が反映されない
```bash
killall Dock; killall Finder; killall cfprefsd
# または再ログイン
```

### Homebrew tap が手動で消えた
```bash
brew tap randomplum/gtkwave    # 手動再追加 → switch すると整合
```

### nvim / Emacs が起動しない
chezmoi external の clone 失敗の可能性:
```bash
chezmoi apply -v   # 詳細ログで状況確認
# 必要なら ~/.config/nvim や ~/.emacs.d を rm -rf して chezmoi apply で再 clone
```

---

## 9. 今後の TODO / 既知の制限

- **VSCode 拡張**: `ms-vscode.cpptools` 系は GUI 手動インストール (proprietary かつ darwin 配信なし)
- **OCaml LSP**: opam switch ABI 互換のため Nix 化せず、`opam install ocaml-lsp-server` で各 switch ごとに管理
- **gcc / libomp / llvm**: brew 残し (macOS toolchain 統合)
- **Emacs venv 連携**: `direnv` + `nix-direnv` を programs.direnv で本格化していない (現状は `buffer-env` で `.envrc` 想定)
- **`~/.vscode/extensions.backup-pre-nix`**: 920MB の旧拡張バックアップ。動作確認後 `rm -rf` で削除可
- **`~/dotfiles/`**: 旧 Stow リポジトリをアーカイブ。数週間運用安定確認後にリネーム/削除
- **homebrew cleanup**: 現状 `cleanup = "none"`。重複ツール (Nix と brew両方にある git, fd等) を整理する場合は `"uninstall"` → `"zap"` 段階引き上げ

---

## 参考リンク

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [home-manager manual](https://nix-community.github.io/home-manager/)
- [chezmoi docs](https://www.chezmoi.io/)
- [nix-vscode-extensions](https://github.com/nix-community/nix-vscode-extensions)
- [MyNixOS (オプション横断検索)](https://mynixos.com/)
- 移行プロセス全体ガイド: `~/dotfiles/nix-macos-guide.md`
