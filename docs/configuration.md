# 構成と管理対象

[README に戻る](../README.md)

設定を変更するときの参照先。パッケージや設定値の完全な一覧は各 Nix ファイルを参照する。

## 管理対象

| 対象 | macOS | Linux |
|---|---|---|
| OS・システム設定 | nix-darwin | OS 側（dnf、systemd 等） |
| CLI・開発ツール | Home Manager | シェルスクリプト（dnf / apt / npm） |
| dotfile | Home Manager | Home Manager |
| Neovim / VS Code / Alacritty | Nix | OS パッケージ（提供リポジトリが必要な場合あり） |
| Emacs 本体 | Homebrew Emacs Plus | Nix（Emacs 31.1 PGTK） |
| Emacs 設定 / デーモン | Home Manager / launchd | Home Manager / systemd user service |
| Firefox・Chrome・Anki・Zotero・Bitwarden・Kiwix 等 | Homebrew Cask | nix-flatpak（ユーザ単位） |
| Firefox のプロファイル・設定・拡張機能 | Firefox 自身 / Firefox Sync | Firefox 自身 / Firefox Sync |
| LM Studio | この構成では導入しない | Flatpak |
| Prism Launcher / Moonlight | Nix | この構成では導入しない |
| Codex | Homebrew Cask | 別途導入 |
| Pi | Nix / Home Manager | シェルスクリプト（npm） |
| VirtualBox | Homebrew Cask | シェルスクリプト（Fedora は RPM Fusion、apt は配布パッケージ） |
| CUDA 本体・PATH・環境変数 | この構成では導入しない | 後日、専用スクリプトで導入予定 |
| SSH agent の接続先 | `~/.bitwarden-ssh-agent.sock` | `~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock` |

macOS の JetBrains IDE は Homebrew Cask の Toolbox から導入する。Nix 版 IDE や専用 overlay は現在の構成に含まれない。

Linux の Tailscale と GNOME の AppIndicator 拡張は OS 側で別途導入する。Flatpak 本体と desktop portal も OS 側の管理対象。RDP を使うホストの既存運用メモでは、待受は 3389/TCP、firewalld の許可対象は 3389/TCP・UDP としているが、このリポジトリには設定を含まない。

## 変更先の一覧

| 変更したい内容 | ファイル |
|---|---|
| inputs、overlay、OS ごとの構成 | [`flake.nix`](../flake.nix) |
| ユーザ名・ホスト名・アーキテクチャ | [`private/user.nix.example`](../private/user.nix.example) をコピーして `private/user.nix` を作成 |
| 共通パッケージ・LSP・formatter、macOS の `.app` 配置 | [`home/default.nix`](../home/default.nix) |
| macOS の GUI アプリ・Homebrew formula / tap | [`darwin/homebrew.nix`](../darwin/homebrew.nix) |
| macOS の Nix・zsh・Emacs デーモン | [`darwin/default.nix`](../darwin/default.nix) |
| macOS の外観・キーボード・DNS | [`darwin/defaults.nix`](../darwin/defaults.nix)、[`darwin/symbolic-hotkeys.nix`](../darwin/symbolic-hotkeys.nix) |
| macOS の SSH agent | [`darwin/bitwarden.nix`](../darwin/bitwarden.nix) |
| Linux の汎用パッケージ・VirtualBox | [`scripts/install-linux-software.sh`](../scripts/install-linux-software.sh) |
| Linux の Emacs デーモン・SSH agent・フォント・GPU 連携 | [`linux/default.nix`](../linux/default.nix) |
| Linux の GUI アプリ・Flatpak 更新 | [`linux/flatpak.nix`](../linux/flatpak.nix) |
| Emacs 本体・設定の配置 | [`home/emacs.nix`](../home/emacs.nix) |
| Emacs の操作・パッケージ設定 | [`home/emacs/init.el`](../home/emacs/init.el)、[`early-init.el`](../home/emacs/early-init.el) |
| VS Code の拡張・C++ スニペット | [`home/vscode.nix`](../home/vscode.nix) |
| VS Code の User 設定・スニペットの内容 | [`home/vscode-settings.json`](../home/vscode-settings.json)、[`home/cpp-snippets.json`](../home/cpp-snippets.json) |
| シェル・プロンプト | [`home/zsh.nix`](../home/zsh.nix)、[`home/bash.nix`](../home/bash.nix)、[`home/starship.nix`](../home/starship.nix) |
| Git 設定 | [`home/git.nix`](../home/git.nix)、[`home/dotfiles/gitconfig`](../home/dotfiles/gitconfig) |
| Alacritty・tmux・latexmk | [`home/dotfiles.nix`](../home/dotfiles.nix)、[`home/dotfiles/`](../home/dotfiles/) |
| 世代と Nix store の清掃 | [`home/nh.nix`](../home/nh.nix) |

fzf・direnv はパッケージのみ導入する。専用の Home Manager モジュールやシェル統合、nix-direnv は現在宣言していない。

## 設定の読み込み

- macOS: `flake.nix` → `darwin/` + `home/`
- Linux: `flake.nix` → `home/` + `linux/` + nix-flatpak の Home Manager モジュール

`private/user.nix` の `username` / `hostname` / `system` から次の output を作る。日常のコマンドでは `default` を使える。

| OS | output |
|---|---|
| macOS | `darwinConfigurations.<host>` / `darwinConfigurations.default` |
| Linux | `homeConfigurations."<user>@<host>"` / `homeConfigurations.default` |

共通 overlay は `nix-vscode-extensions`。unfree パッケージを許可している。

`private/user.nix` は実ユーザの **`~/nix-config/private/user.nix` を絶対パスで import** するため、評価・ビルド・適用には `--impure` が必要。sudo 経由では `SUDO_USER` から実ユーザのホームを復元する。配置先を変える場合は `flake.nix` の読み込み先も変更する。

このファイルは `.gitignore` の対象であり、Git への強制追加は不要。テンプレートのコメントに残る `intent-to-add` / `skip-worktree` は旧方式の案内なので実行しない。

## ホストごとに確認する設定

- **macOS**: `hostPlatform` と Emacs の `/opt/homebrew` パスは Apple Silicon 前提。内蔵キーボードの LocationID と、Wi-Fi / Thunderbolt Ethernet のネットワークサービス名を確認する。
- **Linux**: GPU 連携は有効なので、NVIDIA の版・ハッシュをホストに合わせる。VirtualBox は[セットアップ手順](setup.md#3-virtualbox)を参照。CUDA の導入・パス設定は後日追加予定。[GPU・CUDA の方針](linux-gpu.md)を参照。
- **手動設定**: アカウントへのログイン、プライバシー権限、SSH 接続先、アプリのデータは各ホストで用意する。

macOS の内蔵キーボードでは Caps Lock / 左 Control を交換し、ログイン時に `hidutil` で再適用する。外部キーボードには適用しない。Control+Space と F11 の OS 側割り当ては無効化している。

## 過去の構成との違い

GNU Stow + Brewfile から Nix / nix-darwin へ移行し、dotfile は Home Manager に集約した。途中で使っていた chezmoi と NvChad の復元手順は現在の導入に不要。Neovim はデフォルト設定で使う。

旧構築ガイドは現行手順と重複し、廃止済みの構成も含むため削除した。移行当時の説明が必要な場合は Git 履歴を参照する。
