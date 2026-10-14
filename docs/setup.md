# 新しいマシンのセットアップ

[README に戻る](../README.md)

- [事前準備](#事前準備)
- [macOS](#macos)
- [Linux](#linux)
- [導入後の手動設定](#導入後の手動設定)

## 事前準備

1. 既存環境へ適用する場合は、dotfile と必要なアプリデータをバックアップする。
2. リポジトリの取得に必要な GitHub の認証を用意する。SSH を使う場合は Bitwarden SSH agent または準備済みの鍵を使う。
3. `private/user.nix` に設定するユーザ名・ホスト名・アーキテクチャを確認する。

配置先は **`~/nix-config`** を前提とする。`private/user.nix` は Git 管理外に置き、評価・適用には `--impure` を付ける。テンプレートのコメントに残る `git add -N -f` / `skip-worktree` の手順は実行しない。

初回適用でも、macOS は宣言外の Homebrew formula / cask、Linux は宣言外の **ユーザ単位** Flatpak を削除する。継続利用するものは、先に [`darwin/homebrew.nix`](../darwin/homebrew.nix) または [`linux/flatpak.nix`](../linux/flatpak.nix) へ追加する。システム単位の Flatpak は管理対象外。

## macOS

Apple Silicon を前提とする。Homebrew 自体はこの構成ではインストールしない。

### 1. Xcode CLT・Nix・Homebrew を用意する

```bash
xcode-select --install
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

Nix の導入後は新しいターミナルを開き、`nix --version` を確認する。[Homebrew の導入手順](https://brew.sh/)に従い、`/opt/homebrew/bin/brew` を使える状態にする。Nix インストーラーは [NixOS/nix-installer](https://github.com/NixOS/nix-installer) を参照。

### 2. Bitwarden とリポジトリを用意する

```bash
brew install --cask bitwarden
```

Bitwarden にログインし、SSH agent を有効にしてから実行する。

```bash
export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
ssh-add -l

# <your-account> を自分のアカウントに置き換える
git clone git@github.com:<your-account>/nix-config.git ~/nix-config
cd ~/nix-config
cp private/user.nix.example private/user.nix
vi private/user.nix
```

`username` は `whoami`、`hostname` は `scutil --get LocalHostName` の出力に合わせ、`system` は `"aarch64-darwin"` にする。[ホスト固有の設定](configuration.md#ホストごとに確認する設定)も適用前に確認する。

### 3. 初回適用

```bash
cd ~/nix-config
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#default --impure
exec zsh -l
```

初回起動方法は [nix-darwin の導入手順](https://github.com/nix-darwin/nix-darwin#step-2-installing-nix-darwin)を参照。既存 dotfile と競合する場合、Home Manager は `.hmbak` に退避する。同名のバックアップがある場合は内容を確認し、別名へ移してから再実行する。

## Linux

systemd を使い、`nix` / `nix-daemon` を標準リポジトリまたは EPEL から導入できる Fedora / Rocky Linux / AlmaLinux 等を対象とする。アーキテクチャは `x86_64` / `aarch64`。Home Manager はユーザ環境とユーザ単位の Flatpak を管理し、OS パッケージ・SELinux・ファイアウォール等は OS 側で管理する。

### 1. OS 側の前提パッケージを用意する

Rocky Linux / AlmaLinux / RHEL では、必要に応じて先に EPEL を有効にする。

```bash
dnf info nix nix-daemon
sudo dnf install -y \
  nix nix-daemon git flatpak xdg-desktop-portal xdg-desktop-portal-gtk
sudo systemctl enable --now nix-daemon
```

`dnf info` で両パッケージが見つからない環境はこの手順の対象外。KDE Plasma では GTK backend の代わりに、または追加で `xdg-desktop-portal-kde` を導入する。

新しいログインシェルを開いて確認する。flakes が未有効なら、`~/.config/nix/nix.conf` に `experimental-features = nix-command flakes` を設定する。

```bash
nix --version
nix store ping
nix shell nixpkgs#hello --command hello
```

Fedora の構成例は導入後の `/usr/share/doc/nix-core/README.fedora.md`、[Fedora の Nix パッケージ案内](https://fedoraproject.org/wiki/Changes/Nix_package_tool)を参照。

### 2. リポジトリとホスト情報を用意する

```bash
# <your-account> を置き換える。非公開リポジトリは PAT または準備済みの SSH 鍵で認証する
git clone https://github.com/<your-account>/nix-config.git ~/nix-config
cd ~/nix-config
cp private/user.nix.example private/user.nix
whoami
hostnamectl --static
uname -m
vi private/user.nix
```

`username` / `hostname` は上記の出力に合わせる。`system` は `uname -m` が `x86_64` なら `"x86_64-linux"`、`aarch64` なら `"aarch64-linux"` にする。

**初回適用前に [`linux/default.nix`](../linux/default.nix) を確認する。** NVIDIA の版・ハッシュと CUDA のパスは特定ホスト向けに固定されている。Mesa を使う場合は `nvidia.enable = false` にする。[GPU・CUDA の手順](linux-gpu.md)に従って変更し、必要なドライバー・CUDA SDK・コンテナ基盤を OS 側へ導入する。

### 3. 初回適用と確認

通常ユーザで実行する。`-b hmbak` は競合する既存ファイルを `.hmbak` へ退避する。同名のバックアップがある場合は内容を確認して別名へ移す。

```bash
cd ~/nix-config
nix run home-manager/master -- switch --flake .#default --impure -b hmbak
exec "$SHELL" -l
```

```bash
home-manager generations
flatpak list --user
systemctl --user list-timers '*flatpak*'
```

[Nix 版 GUI の GPU 連携](linux-gpu.md#nix-版-gui-の-gpu-連携)に従い、`non-nixos-gpu-setup` も実行する。

```bash
flatpak run com.bitwarden.desktop
```

Bitwarden へログインして SSH agent を有効にし、新しいシェルで `printenv SSH_AUTH_SOCK` と `ssh-add -l` を確認する。Flatpak の Flathub remote と週次更新 timer は `linux/flatpak.nix` が管理する。

## 導入後の手動設定

- App Store・Bitwarden 等へのログイン、macOS のプライバシー権限、Bluetooth のペアリング。
- 必要な `~/.ssh/config`、API キー、アプリのデータの用意。SSH 鍵は Bitwarden SSH agent で扱う。
- [Firefox の設定・拡張機能の移行](firefox.md)。
- [Emacs・Lean・Pi 等の初回設定](applications.md)。

2 回目以降の適用と依存関係の更新は[日常運用](maintenance.md)を参照する。Neovim の外部設定リポジトリや chezmoi の復元は不要。
