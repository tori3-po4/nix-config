# nix-config

macOS は **nix-darwin + Home Manager**、Linux は **standalone Home Manager** で管理する個人用設定。CLI・開発ツール・dotfile をこのリポジトリに集約し、GUI アプリは Nix / Homebrew / Flatpak で管理する。

## ドキュメント

| やりたいこと | 読むドキュメント |
|---|---|
| 新しいマシンに導入する | [セットアップ](docs/setup.md)（[macOS](docs/setup.md#macos) / [Linux](docs/setup.md#linux)） |
| 設定を変更する場所を探す | [構成と管理対象](docs/configuration.md) |
| 更新・ロールバック・不具合対応をする | [日常運用とトラブルシュート](docs/maintenance.md) |
| Emacs・VS Code・Lean・Pi・Kiwix を使う | [アプリ別の設定と使い方](docs/applications.md) |
| Linux の GPU・CUDA を設定する | [Linux の GPU・CUDA](docs/linux-gpu.md) |
| Firefox の設定・拡張機能を移行する | [Firefox の移行](docs/firefox.md) |
| Windows のゲームを Mac から遊ぶ | [Sunshine + Moonlight](docs/sunshine-moonlight.md) |

## 対応環境

| 環境 | 構成 |
|---|---|
| macOS / Apple Silicon (`aarch64-darwin`) | nix-darwin でシステム設定・Homebrew、Home Manager でユーザ環境を管理 |
| Linux (`x86_64-linux` / `aarch64-linux`) | Home Manager でユーザ環境とユーザ単位の Flatpak を管理。OS は dnf 等で管理 |

Linux の導入手順は、systemd と dnf を使い `nix` / `nix-daemon` を導入できる環境を対象とする。NixOS 用の output は未定義。GPU・CUDA、macOS のキーボードやネットワーク設定はホストに合わせて調整する。

## よく使うコマンド

初回導入済みの環境で実行する。`private/user.nix` を実ユーザの `~/nix-config/` から読むため、評価・ビルド・適用には `--impure` が必要。

```bash
# macOS: 設定を反映
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# Linux: 設定を反映（通常ユーザで実行）
home-manager switch --flake ~/nix-config#default --impure
```

依存関係を更新する場合は、`~/nix-config` で `nix flake update` を実行し、対象 OS のビルドを確認してから反映する。[更新・ロールバックの手順](docs/maintenance.md#依存関係の更新)を参照。

Homebrew は適用時、Flatpak は週次でアプリを更新する。どちらも宣言外のアプリを削除する設定があるため、継続利用するものは各設定ファイルへ追加する。詳しくは[更新と削除の範囲](docs/maintenance.md#homebrewflatpak-の更新と削除)を参照。

## リポジトリ構成

```text
nix-config/
├── README.md               # 概要・ドキュメントの入口
├── docs/                   # 導入・運用・アプリ別の手順
├── flake.nix               # inputs、overlay、OS ごとの構成
├── flake.lock              # Nix の依存リビジョン
├── private/
│   ├── user.nix.example    # ホスト・ユーザ情報のテンプレート
│   └── user.nix            # 各ホストで作成（Git 管理外）
├── darwin/                 # macOS のシステム設定・Homebrew
├── linux/                  # Linux のサービス・Flatpak・GPU
└── home/                   # 共通パッケージ・シェル・エディタ・dotfile
```

設定ファイルごとの役割は[変更先の一覧](docs/configuration.md#変更先の一覧)を参照する。

## 管理方針

- パッケージや dotfile の変更はリポジトリ側で行い、上記のコマンドで反映する。
- SSH の秘密鍵は Bitwarden SSH agent を使う。`~/.ssh/config`、API キー、アプリの可変データは各ホストで管理する。
- Firefox の設定・拡張機能は Firefox 自身で管理する。Neovim は本体のみ導入し、デフォルト設定で使う。
- `flake.lock` は Nix の依存を固定する。Homebrew / Flatpak のアプリ、Emacs が取得するパッケージ・文法、elan のツールチェーンは別に更新される。

## 参考リンク

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [Nix パッケージ検索](https://search.nixos.org/packages)
- [MyNixOS（オプション横断検索）](https://mynixos.com/)
