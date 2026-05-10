# Nixで宣言的に管理するmacOS環境構築ガイド

> Nix + nix-darwin + home-manager + chezmoi + Homebrew を組み合わせて、macOSの環境を宣言的に管理するための実践ガイド。

## 目次

1. [全体構想](#1-全体構想)
2. [前提知識と各ツールの役割](#2-前提知識と各ツールの役割)
3. [Nixのインストール](#3-nixのインストール)
4. [全体ロードマップ](#4-全体ロードマップ)
5. [フェーズ0：準備](#5-フェーズ0準備)
6. [フェーズ1：Nix基盤の構築](#6-フェーズ1nix基盤の構築)
7. [フェーズ2：CLIツールのNix化](#7-フェーズ2cliツールのnix化)
8. [フェーズ3：chezmoi導入とStowからの移行](#8-フェーズ3chezmoi導入とstowからの移行)
9. [フェーズ4：Homebrew統合](#9-フェーズ4homebrew統合)
10. [フェーズ5：システム設定のNix化](#10-フェーズ5システム設定のnix化)
11. [フェーズ6：NvChadの整理と運用安定化](#11-フェーズ6nvchadの整理と運用安定化)
12. [トピック別リファレンス](#12-トピック別リファレンス)
13. [新マシンセットアップ](#13-新マシンセットアップ)
14. [トラブルシュート](#14-トラブルシュート)

---

## 1. 全体構想

### 最終的な役割分担

```
┌────────────────────────────────────────────────────────────────┐
│ Nix (nix-darwin)       │ システム設定、Homebrew統合              │
│  - system.defaults     │ Dock, Finder, キーリピート等            │
│  - homebrew.casks      │ GUIアプリ                               │
│  - homebrew.masApps    │ App Storeアプリ                         │
├────────────────────────┼───────────────────────────────────────┤
│ Nix (home-manager)     │ パッケージとツールチェーン              │
│  - home.packages       │ CLIツール、LSP、フォーマッタ            │
│  - programs.neovim     │ Neovim本体のみ                          │
│  - programs.starship等 │ シンプルな設定で済むツール              │
├────────────────────────┼───────────────────────────────────────┤
│ chezmoi                │ 試行錯誤する設定とシークレット          │
│  - dot_zshrc.tmpl      │ シェル設定                              │
│  - dot_config/nvim/    │ NvChad設定一式                          │
│  - encrypted_*         │ シークレット                            │
│  - *.tmpl              │ マシン別差分のあるファイル              │
├────────────────────────┼───────────────────────────────────────┤
│ Homebrew (Caskのみ)    │ Nix管理外のアプリ                       │
│  - Sparkle更新が必要   │ Chrome, VSCode本体, etc                 │
│  - プライバシー権限    │ Slack, Zoom, etc                        │
└────────────────────────┴───────────────────────────────────────┘
```

### Gitリポジトリ構成（推奨：2つに分ける）

```
~/nix-config/                      ← Git repo #1: Nix設定（public可）
├── flake.nix
├── flake.lock
├── darwin/
│   ├── default.nix                ← system.defaults, homebrew
│   └── homebrew.nix
└── home/
    ├── default.nix
    ├── packages.nix
    ├── programs.nix
    └── neovim.nix

~/.local/share/chezmoi/            ← Git repo #2: dotfiles（private推奨）
├── .chezmoiroot
├── dot_zshrc.tmpl
├── dot_gitconfig.tmpl
├── private_dot_ssh/config.tmpl
├── encrypted_dot_aws/credentials.age
└── dot_config/
    ├── nvim/                      ← NvChad
    ├── starship.toml
    └── wezterm/wezterm.lua
```

リポジトリを分ける理由：

- Nix設定はマシン構成、変更頻度が低い
- chezmoi側は日常的に変更
- 公開範囲を変えたい場合がある
- 片方が壊れてももう片方は無事

---

## 2. 前提知識と各ツールの役割

### Nix vs Homebrew vs chezmoi vs GNU Stow

| 観点 | Nix (home-manager) | Homebrew | chezmoi | GNU Stow |
|---|---|---|---|---|
| 管理対象 | パッケージ＋設定 | パッケージ | 設定ファイル | 設定ファイル |
| 配置方法 | シンボリックリンク（読み取り専用） | バイナリ配置 | 実ファイルコピー | シンボリックリンク |
| テンプレート | Nix式 | なし | Goテンプレート | なし |
| シークレット | sops-nix等の追加ツール | なし | 組み込み（age/gpg） | なし |
| マシン別差分 | flakeの分岐 | 困難 | テンプレートで条件分岐 | 手動 |

### macOSでできること・できないこと

**完全にNixで管理可能：**

- システム設定（Dock、Finder、キーリピート、トラックパッド等）
- インストール済みアプリ一式（Cask + masApps + Nix）
- シェル環境、開発ツール、ドットファイル
- エディタ設定、キーリマップ

**Nixでは管理できない（手動セットアップが必要）：**

- macOS初期セットアップ（Apple ID、Wi-Fi等）
- Xcode Command Line Toolsの初回インストール
- App Store / iCloudへの初回サインイン
- TCC（プライバシー権限：カメラ、マイク、画面収録）
- Bluetoothペアリング、Touch ID登録
- Apple純正アプリの細かい設定（メール、メッセージ等）

**現実的な目標：**

「100%全部Nix」ではなく「**新しいMacを買ったら2〜3時間でいつもの環境**」を目指す。8〜9割をカバーできれば実用的。

---

## 3. Nixのインストール

### インストーラの選択肢（2026年5月現在）

2025年にDeterminate Systems社が方針転換し、現在は3つの選択肢がある：

| 選択肢 | 入るもの | 推奨度 |
|---|---|---|
| **NixOS Foundation fork** | 素のNix | ★★★ 推奨 |
| Determinate Nix Installer | Determinate Nix（独自版） | ★★ 大規模利用向け |
| 公式shellスクリプト | 素のNix（手動設定多い） | ★ 旧来 |

### 推奨：NixOS Foundation fork

```bash
# 事前準備
xcode-select --install

# Nixインストール
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

**新しいターミナルウィンドウを開いて**動作確認：

```bash
nix --version
nix run nixpkgs#hello
# Hello, world! と出れば成功
```

### Determinate版を使う場合の注意

`pkgs.nix` と nix-darwin の `nix.enable` が衝突するので、`darwin/default.nix` で `nix.enable = false;` を書く必要がある。foundation fork なら不要。

---

## 4. 全体ロードマップ

```
フェーズ0：準備                              （半日）
    ↓
フェーズ1：Nix基盤の構築                      （1日）
    ↓
フェーズ2：CLIツールのNix化                   （1週間）
    ↓
フェーズ3：chezmoiの導入とStowからの移行       （2〜3日）
    ↓
フェーズ4：Homebrew統合                       （3日）
    ↓
フェーズ5：システム設定のNix化                 （3日〜1週間）
    ↓
フェーズ6：NvChadの整理と運用安定化            （継続）
```

各フェーズの間に最低数日は置いて、新構成で日常作業ができることを確認してから進む。

### 進む判断基準まとめ

```
フェーズ0 → 1: 現状記録がGitにある
フェーズ1 → 2: darwin-rebuild switch が成功し、テストツールが動く
フェーズ2 → 3: CLIツール20個以上がNix管理、1週間使って問題ない
フェーズ3 → 4: chezmoi で全dotfile管理、新マシン手順が頭にある
フェーズ4 → 5: Homebrew Cask統合、cleanup = "uninstall" 以上で運用
フェーズ5 → 6: system.defaults で主要設定がNix化
フェーズ6 → 完成: NvChad + LSPが完全動作、lazy-lock.json管理下
```

---

## 5. フェーズ0：準備

### 目的

現状の環境を完全に把握し、後で参照できる形で記録する。**何かをインストールする必要はない**。

### 作業

```bash
mkdir -p ~/nix-migration
cd ~/nix-migration

# 1. 現在のHomebrew状態
brew bundle dump --file=Brewfile.before --force
brew list --formula > brew-formula-before.txt
brew list --cask    > brew-cask-before.txt

# 2. App Storeアプリ（mas未インストールなら "not installed" と表示されるだけ）
mas list > mas-list-before.txt 2>&1 || echo "mas not installed"

# 3. VSCode拡張機能
code --list-extensions > vscode-ext-before.txt 2>&1 || echo "vscode not installed"

# 4. 現在のStow構成
ls -la ~/dotfiles/ > stow-structure.txt
find ~ -maxdepth 3 -lname "*dotfiles*" 2>/dev/null > stow-symlinks.txt

# 5. 主要なdotfileのバックアップ
mkdir -p backups
cp ~/.zshrc                   backups/ 2>/dev/null
cp ~/.zshenv                  backups/ 2>/dev/null
cp ~/.gitconfig               backups/ 2>/dev/null
cp ~/.tmux.conf               backups/ 2>/dev/null
cp -r ~/.ssh                  backups/ssh-backup 2>/dev/null
cp -r ~/.config/nvim          backups/nvim-backup 2>/dev/null

# 6. システム設定
defaults read com.apple.dock      > defaults-dock-before.txt
defaults read com.apple.finder    > defaults-finder-before.txt
defaults read NSGlobalDomain      > defaults-global-before.txt

# 7. 環境変数とPATH
echo $PATH | tr ':' '\n' > current-path.txt
env | sort               > current-env.txt

# 8. Git化
git init && git add . && git commit -m "Initial state before migration"
```

### masについての補足

`mas` はステップ0で**インストールする必要なし**。

- 既に使っていれば一覧が取れる
- 使っていなければ無視
- 実際に必要になるのはフェーズ4

App Storeアプリを使わない場合は、`mas` 関連コマンドはすべてスキップしてOK。

### 成功基準

- [ ] `~/nix-migration/` に現状記録一式がある
- [ ] Gitでcommit済み

---

## 6. フェーズ1：Nix基盤の構築

### 目的

Nixインストール後、最小flakeで `darwin-rebuild switch` が成功する状態を作る。

### ディレクトリ作成

```bash
mkdir -p ~/nix-config/{darwin,home}
cd ~/nix-config
git init
```

### `flake.nix`

```nix
{
  description = "My macOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager }:
  let
    username = "yourname";              # ★whoami の結果
    hostname = "your-mac";              # ★scutil --get LocalHostName
    system   = "aarch64-darwin";        # ★Apple Silicon。Intelは x86_64-darwin
  in {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs username; };
      modules = [
        ./darwin
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${username} = import ./home;
          home-manager.extraSpecialArgs = { inherit inputs username; };
        }
      ];
    };
  };
}
```

### `darwin/default.nix`

```nix
{ pkgs, username, ... }:
{
  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.primaryUser = username;
  
  environment.systemPackages = [];
}
```

### `home/default.nix`

```nix
{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "24.11";
  
  # まず1個だけ試す
  home.packages = with pkgs; [
    ripgrep
  ];
}
```

### 初回適用

```bash
cd ~/nix-config

# 重要: flakesはGit管理されたファイルしか見ない
git add .

# 初回ビルド
nix run nix-darwin -- switch --flake .#your-mac
```

成功後の動作確認：

```bash
which rg
# /etc/profiles/per-user/yourname/bin/rg

rg --version
```

2回目以降は `darwin-rebuild switch --flake ~/nix-config` で適用可能。

```bash
git add . && git commit -m "Initial nix-darwin setup"
```

### 成功基準

- [ ] `darwin-rebuild switch` がエラーなく完了
- [ ] `which rg` がNix管理パスを返す
- [ ] 既存のzsh、git、Homebrewツールが普通に動く

---

## 7. フェーズ2：CLIツールのNix化

### 目的

Homebrewで入れているCLIツールを、1日3〜5個のペースでNix管理に置き換える。

### 仕分け方針

```
[Nix化する]                    [Homebrewに残す]
git, gh, jq, ripgrep, fd      mas（masAppsで自動）
bat, eza, fzf, htop, tree     cocoapods（iOS開発時）
neovim, tmux, starship        macOS固有ツール
node, python3, go, rust       
awscli, terraform, kubectl    
```

### 日次の作業フロー

```bash
# 1. ~/nix-config/home/default.nix に追加
# 2. Git管理に
cd ~/nix-config && git add .

# 3. 適用
darwin-rebuild switch --flake .

# 4. 動作確認
which <new-tool>

# 5. Homebrewから削除
brew uninstall <old-tool>

# 6. 再確認（Nix版が見つかること）
which <new-tool>

# 7. Commit
git commit -am "Add <new-tool>"
```

### 設定例

```nix
{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "24.11";
  
  home.packages = with pkgs; [
    # 基本ツール
    ripgrep jq fd bat eza fzf
    
    # 開発ツール
    gh lazygit delta tokei hyperfine
    
    # 言語処理系
    nodejs_22
    python313
    go
    rustup
    
    # クラウド
    awscli2 terraform kubectl helm k9s
    
    # システム
    htop btop tree watch
    
    # シェル支援
    zoxide starship direnv
    
    # ファイラ
    yazi
  ];
}
```

### 言語処理系の扱い

**シンプル派**：Nixで一本化（上記の例）。再現性重視。

**柔軟派**：mise（旧asdf）でプロジェクト別管理：

```nix
home.packages = with pkgs; [
  mise
];
# .zshrc側で `eval "$(mise activate zsh)"`
```

**プロジェクト別派**：direnv + nix shell：

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

最初はシンプル派、慣れたらプロジェクト別派へ移行が無難。

### 成功基準

- [ ] CLIツール20〜40個がNix管理
- [ ] `brew list --formula` の数が大幅に減少
- [ ] 1週間問題なく使用

**注意**：このフェーズでは `programs.zsh.enable` や `programs.git.enable` をまだ書かない。次フェーズでchezmoiが管理するため。

---

## 8. フェーズ3：chezmoi導入とStowからの移行

### 目的

GNU Stowからchezmoiに移行し、ドットファイル管理を確立する。

### chezmoiの利点（GNU Stowと比較）

1. **テンプレート機能**：マシン・OS別の差分を1ファイルで
2. **シークレット管理**：age/gpgで暗号化が組み込み
3. **実ファイル配置**：シンボリックリンクではないので試行錯誤しやすい
4. **`chezmoi init --apply` 一発で復元**：新マシンセットアップが速い

### Nix側でchezmoiを入れる

```nix
# home/default.nix
home.packages = with pkgs; [
  chezmoi
  age
];
```

```bash
darwin-rebuild switch --flake ~/nix-config
which chezmoi
```

### Stowからの移行手順

#### 1. Stowをアンスタウ

```bash
cd ~/dotfiles
git add -A && git commit -m "Pre-migration snapshot"

# 管理しているパッケージを全部
stow -D bash zsh git tmux vim ssh
```

#### 2. 実ファイルとして配置

```bash
cp ~/dotfiles/zsh/.zshrc        ~/
cp ~/dotfiles/git/.gitconfig    ~/
cp ~/dotfiles/tmux/.tmux.conf   ~/
cp -r ~/dotfiles/ssh/.ssh       ~/
cp -r ~/dotfiles/nvim/.config/nvim ~/.config/
```

#### 3. age暗号化キーの生成

```bash
mkdir -p ~/.config/chezmoi
age-keygen -o ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# パブリックキーをメモ
grep "public key" ~/.config/chezmoi/key.txt
```

**重要**：このキーを**1Password等にバックアップ**する。失うと暗号化ファイルが復号できなくなる。

#### 4. chezmoi初期化

```bash
chezmoi init
```

`~/.config/chezmoi/chezmoi.toml`：

```toml
encryption = "age"

[age]
    identity = "~/.config/chezmoi/key.txt"
    recipient = "age1xxx..."   # ★パブリックキー
```

#### 5. dotfile取り込み

```bash
chezmoi add ~/.zshrc
chezmoi add ~/.gitconfig
chezmoi add ~/.tmux.conf
chezmoi add ~/.config/nvim
chezmoi add ~/.config/starship.toml

# シークレットは暗号化付き
chezmoi add --encrypt ~/.ssh/config
chezmoi add --encrypt ~/.aws/credentials
```

#### 6. テンプレート化（任意）

```bash
chezmoi chattr +template ~/.gitconfig
chezmoi edit ~/.gitconfig
```

`.gitconfig.tmpl` 例：

```
[user]
    name = Your Name
{{ if eq .chezmoi.hostname "work-mac" -}}
    email = work@company.com
{{ else -}}
    email = personal@example.com
{{ end -}}

[init]
    defaultBranch = main
[pull]
    rebase = true
```

#### 7. リポジトリのGit化

```bash
chezmoi cd

git init
git add .
git commit -m "Initial chezmoi repository"

git remote add origin git@github.com:yourname/dotfiles.git
git branch -M main
git push -u origin main

exit
```

#### 8. 旧Stowリポジトリ退避

```bash
mv ~/dotfiles ~/dotfiles-stow-backup-$(date +%Y%m%d)
# 数週間様子を見て問題なければ削除
```

### Nix側との衝突を避ける

home-managerと同じファイルを取り合わないように、**chezmoi管理するファイルは `programs.*.enable` を書かない**：

```nix
# home/default.nix
{
  # ❌ chezmoi で .zshrc を管理するので、これは使わない
  # programs.zsh.enable = true;
  
  # ❌ 同上
  # programs.git.enable = true;
  
  # ✅ パッケージはNix
  home.packages = with pkgs; [
    zsh starship fzf zoxide
  ];
  
  # ✅ シェルから呼ばれるツールの本体は入れる
  programs.starship = {
    enable = true;
    enableZshIntegration = false;   # zshの設定はchezmoi側
  };
}
```

### chezmoi管理の `.zshrc.tmpl` 例

```sh
# Nix profileのPATH
export PATH="$HOME/.nix-profile/bin:$PATH"

# Nix管理のツールを起動
eval "$(starship init zsh)"
source <(fzf --zsh)
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# OS別
{{ if eq .chezmoi.os "darwin" -}}
export HOMEBREW_PREFIX="/opt/homebrew"
{{ else if eq .chezmoi.os "linux" -}}
{{ end }}

# エイリアス
alias ll='eza -l'
alias cat='bat'
```

### 日常ワークフロー

```bash
# 編集
chezmoi edit ~/.zshrc

# 適用
chezmoi apply

# Gitにcommit
chezmoi cd
git add . && git commit -m "Update zsh aliases" && git push
exit
```

### 成功基準

- [ ] `chezmoi managed` で全dotfileが管理下
- [ ] `chezmoi diff` で差分なし
- [ ] シークレットが暗号化済み
- [ ] GitHubにpush済み

---

## 9. フェーズ4：Homebrew統合

### 目的

GUIアプリ（Cask）とApp Storeアプリをnix-darwinの `homebrew` モジュールで管理。

### `darwin/homebrew.nix` 作成

```nix
{
  homebrew = {
    enable = true;
    
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";    # ★最初は絶対 "none"
    };
    
    # mas は masApps があれば自動で追加されるので明示不要
    brews = [
      # "cocoapods"   # iOS開発するなら
    ];
    
    casks = [
      "google-chrome"
      "firefox"
      "visual-studio-code"
      "slack"
      "1password"
      "rectangle"
      # ...Brewfile.before から書き写す
    ];
    
    masApps = {
      # 使うなら
      # "Xcode" = 497799835;
      # "Things 3" = 904280696;
    };
  };
}
```

### `darwin/default.nix` でimport

```nix
{ pkgs, username, ... }:
{
  imports = [ ./homebrew.nix ];
  
  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.primaryUser = username;
}
```

### masの扱い（重要）

`homebrew.masApps` を使う場合、`mas` は**自動的に `homebrew.brews` に追加される**ので明示的に書かなくてよい。

選択肢：

| 方法 | masの入手元 | 設定 |
|---|---|---|
| **A. `homebrew.masApps`** | Homebrew経由（自動） | masAppsだけ書く（推奨） |
| **B. Nix側で完結** | nixpkgs | `home.packages = [ pkgs.mas ];`、手動運用 |
| **C. 両方併用** | nixpkgs（PATH優先） | 両方書く（裏技） |

**推奨**：方式A。シンプルで標準的。

### masAppsの制約事項

- App Storeに**事前にサインイン必須**（手動）
- masAppsから削除しても**自動アンインストールされない**（手動削除が必要）
- 既購入or無料アプリのみ
- 2026年3月時点でnixpkgsのmasが古く、上流変更で問題が起きる事例あり

### cleanup段階的引き上げ

```
最初の数週間  : cleanup = "none"
       ↓
1〜2週間後    : cleanup = "uninstall"  （データは残る）
       ↓
さらに数週間後 : cleanup = "zap"        （完全削除）
```

```nix
# 最終形
onActivation = {
  autoUpdate = true;
  upgrade = true;
  cleanup = "zap";
};
```

### 成功基準

- [ ] すべてのCask、masAppsが `homebrew.nix` に記述
- [ ] `cleanup = "uninstall"` 以上で運用
- [ ] 数週間問題なし

---

## 10. フェーズ5：システム設定のNix化

### 目的

macOSのシステム設定（Dock、Finder、キーリピート等）をNix管理に。

### 基本設定

```nix
# darwin/default.nix
{
  system.defaults = {
    # ===== Dock =====
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.5;
      orientation = "bottom";
      tilesize = 48;
      magnification = false;
      mineffect = "scale";
      show-recents = false;
      mru-spaces = false;
    };
    
    # ===== Finder =====
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = false;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv";   # リスト表示
      FXDefaultSearchScope = "SCcf";   # 現在のフォルダ
      _FXShowPosixPathInTitle = true;
      QuitMenuItem = true;
    };
    
    # ===== グローバル =====
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      
      # キーボード
      InitialKeyRepeat = 14;
      KeyRepeat = 1;
      ApplePressAndHoldEnabled = false;
      
      # 自動補完無効化
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      
      # スクロール
      "com.apple.swipescrolldirection" = false;   # ナチュラル無効
      
      # 高速化
      NSWindowResizeTime = 0.001;
      NSAutomaticWindowAnimationsEnabled = false;
    };
    
    # ===== トラックパッド =====
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };
    
    # ===== スクリーンショット =====
    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
      disable-shadow = true;
    };
    
    # ===== ログイン画面 =====
    loginwindow = {
      GuestEnabled = false;
      DisableConsoleAccess = true;
    };
  };
  
  # キーリマップ
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };
}
```

### CustomUserPreferencesでアプリ設定

ポリシーキーがないアプリの設定を直接書く：

```nix
system.defaults.CustomUserPreferences = {
  "com.google.Chrome" = {
    HomepageLocation = "https://example.com";
    AutofillAddressEnabled = false;
  };
  
  "com.apple.Safari" = {
    AutoOpenSafeDownloads = false;
    ShowFullURLInSmartSearchField = true;
    IncludeDevelopMenu = true;
  };
};
```

### 反映方法

```bash
darwin-rebuild switch --flake ~/nix-config

# 反映確認
killall Dock
killall Finder
killall cfprefsd
# 必要なら再ログイン
```

### Touch ID で sudo

```nix
security.pam.services.sudo_local.touchIdAuth = true;
```

### 成功基準

- [ ] Dock、Finder、キーリピートが期待通り動作
- [ ] `darwin-rebuild switch` 一発で再現可能
- [ ] よく使う設定が `system.defaults` に記述

---

## 11. フェーズ6：NvChadの整理と運用安定化

### 目的

NvChadベースのNeovim設定をchezmoi側で管理し、Nix側でツールチェーン（LSP等）を整える。

### 役割分担

| 領域 | 管理 | 場所 |
|---|---|---|
| Neovim本体 | Nix（home-manager） | `programs.neovim.enable` |
| LSP/フォーマッタ/リンタ | Nix（home-manager） | `home.packages` |
| プラグイン | lazy.nvim | `~/.local/share/nvim/lazy/` |
| プラグインバージョン固定 | `lazy-lock.json` | dotfilesリポジトリ |
| NvChadカスタム設定 | 手書きLua | `~/.config/nvim/`（chezmoi管理） |

### `home/neovim.nix` 作成

```nix
{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    # ★プラグインは書かない（NvChad/lazy.nvimに任せる）
  };

  home.packages = with pkgs; [
    # ビルドツール
    gcc gnumake
    
    # 検索ツール
    ripgrep fd
    
    # LSPサーバー
    lua-language-server
    nil
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    nodePackages.bash-language-server
    rust-analyzer
    pyright
    gopls
    yaml-language-server
    marksman
    
    # フォーマッタ
    stylua
    nodePackages.prettier
    black
    rustfmt
    nixfmt-rfc-style
    shfmt
    
    # リンタ
    ruff
    nodePackages.eslint
    shellcheck
    
    # その他
    tree-sitter
    lazygit
    
    # フォント
    nerd-fonts.jetbrains-mono
  ];
}
```

`home/default.nix` でimport：

```nix
imports = [ ./neovim.nix ];
```

### NvChadのMason無効化

`lua/plugins/init.lua`：

```lua
return {
  -- Mason を無効化
  {
    "williamboman/mason.nvim",
    enabled = false,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    enabled = false,
  },
  
  -- LSP設定はNix管理を使う
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },
}
```

`lua/configs/lspconfig.lua`：

```lua
local lspconfig = require("lspconfig")
local nvlsp = require("nvchad.configs.lspconfig")

local servers = {
  "lua_ls",
  "nil_ls",
  "rust_analyzer",
  "pyright",
  "ts_ls",
  "gopls",
  "marksman",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup({
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  })
end
```

### lazy-lock.json の管理

```bash
# Neovim起動して全プラグインインストール
nvim
:Lazy sync
:q

# lazy-lock.json をchezmoi管理下に
chezmoi cd
git add dot_config/nvim/lazy-lock.json
git commit -m "Lock plugin versions"
git push
```

新マシンでの再現：

```bash
nvim
:Lazy restore   # lazy-lock.json から復元
```

### 成功基準

- [ ] NvChadが起動
- [ ] LSPが正常動作（補完、定義ジャンプ）
- [ ] フォーマッタが動作
- [ ] `lazy-lock.json` がGit管理

---

## 12. トピック別リファレンス

### 12.1 Chrome設定の固定化

#### Linux/NixOS（programs.chromium）

```nix
{
  programs.chromium = {
    enable = true;
    extraOpts = {
      BrowserSignin = 0;
      SyncDisabled = true;
      PasswordManagerEnabled = false;
      HomepageLocation = "https://example.com";
      ExtensionInstallForcelist = [
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
      ];
    };
  };
}
```

#### macOS（plistとして配置）

ロックされるポリシーとして配置：

```nix
{ pkgs, lib, ... }:
let
  chromePolicies = {
    HomepageLocation = "https://example.com";
    BrowserSignin = 0;
    SyncDisabled = true;
    # ...
  };

  chromePolicyPlist =
    pkgs.writeText "com.google.Chrome.plist"
      (lib.generators.toPlist { } chromePolicies);
in
{
  system.activationScripts.chromePolicies.text = ''
    mkdir -p "/Library/Managed Preferences"
    cp ${chromePolicyPlist} "/Library/Managed Preferences/com.google.Chrome.plist"
    chown root:wheel "/Library/Managed Preferences/com.google.Chrome.plist"
    chmod 644 "/Library/Managed Preferences/com.google.Chrome.plist"
  '';
}
```

#### macOS（CustomUserPreferences、ロックなし）

ロック不要、デフォルト値の設定だけしたい場合：

```nix
{
  system.defaults.CustomUserPreferences = {
    "com.google.Chrome" = {
      HomepageLocation = "https://example.com";
      ShowHomeButton = true;
      AutofillAddressEnabled = false;
    };
  };
}
```

UIから変更可能。「組織によって管理されています」表示にはならない。

#### 動作確認

```bash
defaults read com.google.Chrome
defaults read-type com.google.Chrome HomepageLocation

# Chromeで chrome://policy を開く
# ステータスがOKならOK
```

ポリシーキー一覧：`https://chromeenterprise.google/policies/`

### 12.2 GUIアプリの管理戦略

#### 推奨される使い分け

| 対象 | 推奨方法 |
|---|---|
| 商用アプリ（1Password、Things、Tower、Bartender） | Cask |
| ブラウザ（Chrome、Firefox、Arc、Brave） | Cask |
| コミュニケーション系（Slack、Discord、Zoom） | Cask（プライバシー権限のため重要） |
| クリエイティブ系（Figma、Sketch、Notion、Obsidian） | Cask |
| VSCode | Cask（拡張機能の署名問題回避） |
| Docker Desktop / OrbStack | Cask |
| CLIツール全般 | Nix |
| 言語処理系（Node.js、Python、Go、Rust） | Nix |
| クラウドCLI（aws、terraform、kubectl） | Nix |
| 設定をNix管理したいGUI（Alacritty、WezTerm、Emacs） | Nix |
| App Store専売（Xcode、Things 3、Pages等） | masApps |

#### Nixで入れるとSparkle更新で衝突する例

- 多くの商用macOSアプリ
- VSCode（拡張機能の署名検証エラー、特にApple Silicon）
- カメラ・マイク・画面収録権限を要求するアプリ

これらは**Cask一択**。

### 12.3 VSCode設定管理（home-manager）

#### 基本

```nix
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      userSettings = {
        "editor.fontFamily" = "JetBrains Mono, Menlo, monospace";
        "editor.fontSize" = 14;
        "editor.tabSize" = 2;
        "editor.formatOnSave" = true;
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "none";
      };

      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        ms-python.python
        rust-lang.rust-analyzer
      ];
    };
  };
}
```

#### Marketplace拡張機能の利用

`pkgs.vscode-extensions` には主要なものしか入っていない。Marketplace全件を使うには：

```nix
# flake.nix
inputs.nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

# モジュール
nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];

programs.vscode.profiles.default.extensions = with pkgs.vscode-marketplace; [
  github.copilot
  bradlc.vscode-tailwindcss
];
```

#### 落とし穴

- **settings.jsonが読み取り専用になる**：home-managerが配置するファイルはNixストアへのリンクで書き込み禁止。GUIから設定変更できない
- **拡張機能管理が二重になる**：`mutableExtensionsDir = true` でVSCode側からの追加も許可可能だが本末転倒
- **Apple SiliconでのSparkle更新衝突**：本体はCaskで入れ、設定だけhome-managerで管理する分離もあり

#### Cask + 設定だけNix管理

```nix
# nix-darwin
homebrew.casks = [ "visual-studio-code" ];

# home-manager（programs.vscodeは使わない）
home.file."Library/Application Support/Code/User/settings.json".text =
  builtins.toJSON {
    "editor.fontSize" = 14;
    "editor.formatOnSave" = true;
  };
```

### 12.4 Ghostty設定

macOSではNixからのソースビルドが現状不可。3つの選択肢：

#### A. ghostty-bin（公式DMGをNixで再パッケージ）

```nix
programs.ghostty = {
  enable = true;
  package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
  enableZshIntegration = true;
  
  settings = {
    font-family = "JetBrainsMono Nerd Font";
    font-size = 14;
    theme = "tokyonight";
  };
};
```

Sparkle自動更新は壊れる。

#### B. Cask + 設定だけNix管理（推奨）

```nix
# nix-darwin
homebrew.casks = [ "ghostty" ];

# home-manager
programs.ghostty = {
  enable = true;
  package = null;   # ← 本体はインストールしない
  
  settings = {
    font-family = "JetBrainsMono Nerd Font";
    font-size = 14;
  };
};
```

自動更新も正常、設定はNix管理。

#### C. 公式DMGを手動 + 設定Nix管理

最速で最新版に追従したい人向け。Cask不要。

#### sudo時の色問題

```nix
{
  security.sudo.extraConfig = ''
    Defaults env_keep += "TERMINFO"
  '';
}
```

### 12.5 既存設定のエクスポート

#### Homebrew

```bash
brew bundle dump --file=~/nix-migration/Brewfile --force
```

#### VSCode拡張機能

```bash
code --list-extensions > ~/nix-migration/vscode-extensions.txt
```

#### VSCode設定

```bash
cp ~/Library/Application\ Support/Code/User/settings.json    ~/nix-migration/
cp ~/Library/Application\ Support/Code/User/keybindings.json ~/nix-migration/
```

#### App Storeアプリ

```bash
mas list > ~/nix-migration/mas-apps.txt
```

#### macOSシステム設定

```bash
defaults read com.apple.dock      > ~/nix-migration/defaults-dock.txt
defaults read com.apple.finder    > ~/nix-migration/defaults-finder.txt
defaults read NSGlobalDomain      > ~/nix-migration/defaults-global.txt
```

#### シェル設定

```bash
cp ~/.zshrc       ~/nix-migration/
cp ~/.gitconfig   ~/nix-migration/
cp ~/.tmux.conf   ~/nix-migration/
cp ~/.ssh/config  ~/nix-migration/ssh-config
```

### 12.6 Xcode関連とApp Store

#### Xcode Command Line Tools

Nixでは管理不可。Apple純正で入れたまま残す。Nix版のgitなどで上書きする運用。

```bash
xcode-select --install   # 1回だけ手動
```

CLT存在チェック：

```nix
{
  system.activationScripts.checkCLT.text = ''
    if ! /usr/bin/xcode-select -p &>/dev/null; then
      echo "⚠️  Xcode Command Line Tools未インストール"
    fi
  '';
}
```

#### Xcode本体（IDE）

選択肢：

| 方法 | 備考 |
|---|---|
| `homebrew.masApps = { "Xcode" = 497799835; };` | 一番シンプル |
| `xcodes` で複数バージョン管理 | プロジェクト別バージョン固定したい場合 |
| Swift系ツールだけNix | iOS開発しないが、Swift書く場合 |

### 12.7 Minecraft環境

#### macOSで遊ぶ場合

```nix
home.packages = with pkgs; [
  (prismlauncher.override {
    additionalPrograms = [ ffmpeg ];
    jdks = [ 
      graalvmPackages.graalvm-ce 
      zulu8
      zulu17
      zulu21
    ];
  })
];
```

ランチャー本体とJavaのみNix管理。プロファイル・modはランチャーGUIで管理。

#### Linuxでサーバー運営

`Infinidoge/nix-minecraft` が最も成熟：

```nix
services.minecraft-servers = {
  enable = true;
  eula = true;
  
  servers.my-survival = {
    enable = true;
    package = pkgs.fabricServers.fabric-1_21;
    serverProperties = {
      difficulty = "hard";
      view-distance = 16;
    };
    symlinks.mods = pkgs.linkFarmFromDrvs "mods" [
      (pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/.../mod.jar";
        sha512 = "...";
      })
    ];
  };
};
```

mod込みで完全宣言的管理可能。

---

## 13. 新マシンセットアップ

### 想定手順

```bash
# 0. macOS初期セットアップ（手動）
# - Apple ID サインイン
# - iCloud, App Store サインイン

# 1. Xcode CLT（手動）
xcode-select --install

# 2. Nixインストール
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes

# 3. Nix設定取得・適用
git clone https://github.com/yourname/nix-config ~/nix-config
cd ~/nix-config
nix run nix-darwin -- switch --flake .#your-mac

# 4. age key を持ち込む（1Passwordから）
mkdir -p ~/.config/chezmoi
# 1Passwordから key.txt をコピー
chmod 600 ~/.config/chezmoi/key.txt

# 5. chezmoiでdotfile展開
chezmoi init --apply git@github.com:yourname/dotfiles.git

# 6. シェル再読込
exec zsh

# 7. Neovim初回起動でプラグイン取得
nvim
:Lazy restore
:q
```

### 残る手動作業

- App Store サインイン
- プライバシー権限の許可（カメラ、マイク、画面収録）
- Bluetoothデバイスのペアリング
- 1Password等のパスワードマネージャ初回ログイン

合計30分程度。本質的な開発環境は2〜3時間で再現可能。

---

## 14. トラブルシュート

### よくあるエラー

#### file not found / path does not exist

**原因**：`git add` していないファイルを参照。

```bash
git add . && git status
```

#### attribute 'foo' missing

**原因**：オプション名のtypoまたは存在しないオプション。

**対処**：[MyNixOS](https://mynixos.com/) でオプション名を検索。

#### 適用後に設定が反映されない

```bash
killall cfprefsd
killall Dock
killall Finder
# または再ログイン
```

#### conflicting definitions

**原因**：home-managerとnix-darwinで同じものを2回定義。

**対処**：ユーザー単位はhome-manager、システム単位はnix-darwinに寄せる。

#### Cannot determine version of...

```bash
nix flake update
darwin-rebuild switch --flake .
```

### Rollback機能

#### nix-darwin

```bash
# 直前の世代に戻す
darwin-rebuild rollback

# 世代一覧
darwin-rebuild --list-generations

# 特定の世代に戻す
darwin-rebuild switch --switch-generation 42
```

#### chezmoi

```bash
chezmoi cd
git log --oneline
git checkout <safe-hash>
chezmoi apply
```

### 最悪のケース：nix-darwinごと壊れた

```bash
# 一時的にアンインストール
/run/current-system/sw/bin/darwin-uninstaller
# 最初からやり直し
```

### `chezmoi managed` でファイルが見えない

```bash
chezmoi cd
ls -la
# ファイルがあるかGit統計で確認
git ls-files
```

### Touch IDがsudoで効かない

`security.pam.services.sudo_local.touchIdAuth = true;` を `darwin/default.nix` に追加。

### NvChadでLSPが動かない

1. `which lua-language-server` でNix版が見えるか確認
2. NvChadのMason無効化が正しく適用されているか確認
3. `:LspInfo` でLSPが認識されているか確認

---

## 学習リソース

### 公式・準公式

- [NixOS Wiki - macOS](https://wiki.nixos.org/wiki/Nix-darwin)
- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [home-manager manual](https://nix-community.github.io/home-manager/)

### オプション検索

- [MyNixOS](https://mynixos.com/)：横断検索
- [search.nixos.org](https://search.nixos.org/packages)：パッケージ検索
- [home-manager option search](https://home-manager-options.extranix.com/)

### 実例集

GitHubで「dotfiles nix-darwin」検索。

### 動画

vimjoyer（YouTube）：Nix関連解説動画。

---

## 心構え

1. **完璧を目指さない**：8割管理できれば実用上十分
2. **commit駆動**：動いた瞬間にcommit、これだけで安全性が段違い
3. **既存環境を壊さない**：新環境ができてから旧環境を削除
4. **エラーは怖くない**：rollbackで戻せるので試行錯誤を恐れない
5. **わからないことは検索より人に聞く**：[NixOS Discourse](https://discourse.nixos.org/) や Discord

---

## 全体スケジュール例

```
Week 1:  フェーズ0 + 1 + 2前半
         （準備、Nix基盤、CLIツール5〜10個）

Week 2:  フェーズ2後半
         （CLIツール20〜30個、シェル設定はまだ手動）

Week 3:  フェーズ3
         （chezmoi移行、ドットファイル整理）

Week 4:  フェーズ4
         （Homebrew統合、cleanup段階引き上げ）

Week 5:  フェーズ5
         （システム設定Nix化）

Week 6+: フェーズ6 + 安定化
         （NvChad整理、cleanup = "zap"、運用本格化）
```

1.5ヶ月で完全な宣言的環境。本業の合間でやる前提で、もっと短くも長くもなり得る。

---

## 付録：ディレクトリ構成テンプレート

### `~/nix-config/`

```
nix-config/
├── flake.nix
├── flake.lock
├── README.md                      ← このマシン固有のメモ
├── darwin/
│   ├── default.nix                ← system.defaults
│   └── homebrew.nix               ← Cask, masApps
└── home/
    ├── default.nix                ← entry point, imports
    ├── packages.nix               ← home.packages
    ├── programs.nix               ← starship, direnv等
    ├── neovim.nix                 ← Neovim本体とLSP
    └── git.nix                    ← Nix管理にする場合のみ
```

### `~/.local/share/chezmoi/`

```
chezmoi/
├── .chezmoiroot
├── .chezmoiignore
├── .chezmoi.toml.tmpl             ← 初期セットアップ用テンプレート
├── dot_zshrc.tmpl
├── dot_zshenv.tmpl
├── dot_gitconfig.tmpl
├── dot_tmux.conf
├── private_dot_ssh/
│   └── config.tmpl
├── encrypted_dot_aws/
│   └── credentials.age
└── dot_config/
    ├── nvim/
    │   ├── init.lua
    │   ├── lazy-lock.json         ← ★Git管理
    │   └── lua/
    │       ├── chadrc.lua
    │       ├── plugins/
    │       └── configs/
    │           └── lspconfig.lua
    ├── starship.toml
    └── wezterm/
        └── wezterm.lua
```

---

*このガイドは特定の構成（Apple Silicon Mac、NvChadベースNeovim、chezmoi併用）を前提としていますが、各章は独立しているので必要な部分だけ参照してください。*
