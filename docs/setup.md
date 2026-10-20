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

Linux の汎用パッケージと VirtualBox は [`scripts/install-linux-software.sh`](../scripts/install-linux-software.sh) で導入する。通常ユーザで実行する。Fedora / dnf を主対象とし、Ubuntu / Debian には apt 経路を用意している。パッケージの提供状況はディストリビューション・版によって異なる。Emacs、シェル設定、ユーザ単位の Flatpak は Home Manager が管理する。

```bash
bash scripts/install-linux-software.sh --dry-run
bash scripts/install-linux-software.sh
```

CUDA 本体と PATH・環境変数は後日、専用スクリプトで導入する予定で、現時点の設定には含めない。Nix 版 Emacs 用の GPU 連携は有効。初回適用前に `linux/default.nix` の NVIDIA の版・ハッシュをホストに合わせる。Mesa を使う場合を含め、[GPU 連携の手順](linux-gpu.md)を参照する。

### 3. VirtualBox

上記スクリプトで既定で導入するため、`--with-virtualbox` は不要。除外する場合だけ `--no-virtualbox` を付ける。この導入経路は x86_64 が対象で、aarch64 ではメッセージを表示してスキップする。

- **Fedora**: RPM Fusion free を必要に応じて登録し、`VirtualBox`・`akmod-VirtualBox`・実行中のカーネルに対応する `kernel-devel` を導入する。`akmods` でモジュールを構築し、`vboxdrv.service` を有効化・起動する。本体とモジュールの依存関係は RPM Fusion が管理する。
- **Ubuntu / apt**: `virtualbox` の候補がない場合は `software-properties-common` を導入し、universe / multiverse を自動で有効化する。
- **Debian 12 / 13（bookworm / trixie）/ apt**: 候補がない場合は `fasttrack-archive-keyring` を導入し、backports と [Debian Fast Track](https://fasttrack.debian.net/) を `/etc/apt/sources.list.d/nix-config-virtualbox.sources` に登録する。Debian の版に対応した署名鍵を指定する。

apt 側も追加フラグやリポジトリの事前設定は不要。必要なリポジトリを設定・更新してから、`virtualbox`・`virtualbox-dkms`・`virtualbox-qt`・ビルドツール・実行中のカーネルのヘッダーを導入し、`vboxdrv` を読み込む。既にパッケージ候補がある場合は既存のリポジトリを使う。リポジトリ設定・インストールの失敗はエラーとして停止する。その他の apt 系 OS では候補がない場合に停止するため、リポジトリを別途用意するか `--no-virtualbox` で除外する。

`--dry-run` は現在のパッケージ一覧を参照し、リポジトリ設定を含めた実行予定のコマンドを表示する。パッケージ一覧の更新・ファイル変更・インストールは行わない。

導入時に実行ユーザを `vboxusers` に追加するので、一度ログアウト・ログインする。Fedora 以外の dnf 環境では VirtualBox をスキップする。

```bash
VBoxManage --version
modinfo -F version vboxdrv
ls -l /dev/vboxdrv
```

古いカーネルの開発パッケージが配布されていない場合は、OS を更新して新しいカーネルで再起動してから再実行する。Secure Boot 有効時はモジュールの署名と鍵の登録が必要になる場合がある。Fedora は `/usr/share/doc/akmods/README.secureboot`、Ubuntu / Debian は各ディストリビューションの DKMS / MOK 手順に従う。モジュールの構築や読み込みに失敗した場合、スクリプトはそこで停止する。

参考: [RPM Fusion のパッケージ定義](https://github.com/rpmfusion/VirtualBox/blob/master/VirtualBox.spec)、[Ubuntu の VirtualBox パッケージ](https://packages.ubuntu.com/noble/virtualbox)、[Debian Fast Track（Debian 13）](https://fasttrack.debian.net/) / [Debian 12](https://fasttrack.debian.net/bookworm.html)。

### 4. 初回適用と確認

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

[GPU 連携の手順](linux-gpu.md#nix-版-gui-の-gpu-連携)に従って `non-nixos-gpu-setup` を実行する。

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
