# 日常運用とトラブルシュート

[README に戻る](../README.md)

- [設定の反映](#設定の反映)
- [依存関係の更新](#依存関係の更新)
- [ロールバック](#ロールバック)
- [Homebrew・Flatpak の更新と削除](#homebrewflatpak-の更新と削除)
- [世代と Nix store の清掃](#世代と-nix-store-の清掃)
- [トラブルシュート](#トラブルシュート)

## 設定の反映

[変更先の一覧](configuration.md#変更先の一覧)から対象の Nix ファイルや dotfile を編集する。配置後の dotfile は通常 Nix store へのリンクなので、リポジトリ側を変更する。

新規ファイルは適用前に `git add <追加したファイル>` で追跡対象にする。`private/user.nix` は Git 管理外のままにする。

### macOS

```bash
sudo darwin-rebuild switch --flake ~/nix-config#default --impure
```

### Linux

`sudo` を付けず、対象ユーザ自身で実行する。

```bash
home-manager switch --flake ~/nix-config#default --impure
```

どちらも `private/user.nix` を実ユーザの `~/nix-config/` から読むため、`--impure` が必要。

## 依存関係の更新

```bash
cd ~/nix-config
nix flake update
git diff -- flake.lock
```

対象 OS のビルドだけを実行し、成功したら[設定を反映](#設定の反映)する。

```bash
# macOS
nix build ~/nix-config#darwinConfigurations.default.system --impure --no-link

# Linux
home-manager build --flake ~/nix-config#default --impure
```

Pi だけを更新する場合は `nix flake update pi` を使う。アプリ内の自己更新は使わない。

ビルドに失敗した場合は switch を行わず、[更新後のビルド失敗](#更新後にビルドが失敗する)を参照する。

## ロールバック

### macOS

```bash
sudo darwin-rebuild --list-generations
sudo darwin-rebuild --rollback
```

### Linux

```bash
home-manager generations
```

一覧から戻したい世代の `/nix/store/...-home-manager-generation/activate` を実行する。

Homebrew / Flatpak のアプリ、Emacs が取得するパッケージ・Tree-sitter 文法、elan のツールチェーンは、Nix のロールバックだけでは元に戻らない。GC で削除済みの世代も利用できない。

## Homebrew・Flatpak の更新と削除

| 対象 | 更新タイミング | 宣言から外れたアプリ |
|---|---|---|
| macOS / Homebrew | switch 時。`autoUpdate` / `upgrade` / `greedyCasks` が有効 | `cleanup = "uninstall"` により削除 |
| Linux / ユーザ単位の Flatpak | 週次の systemd user timer。activation 時更新は無効 | `uninstallUnmanaged = true` により削除 |

Homebrew の追加先は [`darwin/homebrew.nix`](../darwin/homebrew.nix)、Flatpak は [`linux/flatpak.nix`](../linux/flatpak.nix)。一時的に `brew install --cask <name>` で試したものも、継続利用するなら宣言へ追加する。

システム単位の Flatpak はこの構成の管理対象外。Firefox のプロファイルはアプリ自身が管理し、専用の Flatpak override は宣言していない。

## 世代と Nix store の清掃

[`home/nh.nix`](../home/nh.nix) で `programs.nh.clean` を有効にし、ユーザプロファイルと Nix store を週次で清掃する。設定上の保持条件は `--keep-since 14d --keep 3`（直近 14 日と最低 3 世代）。macOS のシステムプロファイルの世代削除とは別。

**macOS には引数の渡し方の未修正箇所がある。** 現在の `clean.extraArgs` は文字列で、確認した LaunchAgent では `'--keep-since 14d --keep 3'` が一つの引数になっている。保持条件を正しく渡すには `home/nh.nix` で `extraArgs = [ "--keep-since" "14d" "--keep" "3" ];` とする必要がある。Linux の systemd では文字列が引数に分割される。

## トラブルシュート

### `private/user.nix` を読み込めない

`~/nix-config/private/user.nix` が存在し、`username` / `hostname` / `system` が記入されていることと、コマンドに `--impure` があることを確認する。現在の flake は絶対パスから読むため、Git への登録は不要。[読み込みの仕組み](configuration.md#設定の読み込み)を参照。

### `system activation must now be run as root`

macOS の `darwin-rebuild switch` に `sudo` を付ける。Linux の `home-manager switch` は通常ユーザで実行する。

### 既存ファイルと競合する

`Existing file ... would be clobbered` は、Home Manager が配置先の既存ファイルを上書きできない場合に出る。

- macOS は `flake.nix` の `home-manager.backupFileExtension = "hmbak"` で退避する。
- Linux は `home-manager switch -b hmbak --flake ~/nix-config#default --impure` を使う。
- 同名の `.hmbak` が既にある場合は、内容を確認して別名へ移してから再実行する。

### 新規ファイルが見つからない

追加したモジュールや dotfile が Git の追跡対象か確認する。通常の構成ファイルは `git add <ファイル>` してから再実行する。`private/user.nix` はこの手順の対象外。

### `flake.lock` が root 所有になる

macOS で所有者を確認し、必要な場合だけ修正する。

```bash
ls -l ~/nix-config/flake.lock
sudo chown "$(id -u):staff" ~/nix-config/flake.lock
```

### アプリの更新・GC が権限エラーになる

macOS で `fchmodat ... Operation not permitted` 等が出る場合は、「システム設定 → プライバシーとセキュリティ → アプリ管理」で実行元のターミナル／エディタを許可し、そのアプリを再起動する。

macOS の `.app` は、Spotlight から見つけられるよう `targets.darwin.copyApps` で `~/Applications` 以下へコピーする設定にしている。

### unfree パッケージが拒否される

`flake.nix` の `allowUnfree = true` が対象構成に適用されているか確認する。

### VS Code 拡張が Darwin 向けに見つからない

`vscode-extension-* removed on aarch64-darwin` 等が出る場合は、拡張の取得元を確認する。この構成では cpptools に nixpkgs 同梱の `pkgs.vscode-extensions.ms-vscode.cpptools` を使う。拡張は [`home/vscode.nix`](../home/vscode.nix) で管理する。[VS Code の設定](applications.md#vs-code-の設定拡張管理)も参照。

### `attribute 'foo' missing` / `option does not exist`

エラー位置の属性・オプション名と、使用中の依存リビジョンを確認する。[nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/) や [Home Manager manual](https://nix-community.github.io/home-manager/) で該当するオプションを調べる。macOS の defaults に専用オプションがない場合は `CustomUserPreferences` も検討する。

### 更新後にビルドが失敗する

対象 OS のビルドを行い、失敗したパッケージやオプションを確認する。

```bash
# macOS
nix build ~/nix-config#darwinConfigurations.default.system --impure --no-link --keep-going

# Linux
nix build ~/nix-config#homeConfigurations.default.activationPackage --impure --no-link --keep-going
```

`git diff -- flake.lock` で更新内容を確認し、上流の修正状況を調べる。必要に応じて動作していた lock に戻すか、対象パッケージだけを別リビジョンで固定する。

### macOS の defaults が反映されない

対象アプリの再起動または再ログインを試す。Dock・Finder の再起動が必要な場合は次を実行する。

```bash
killall Dock
killall Finder
killall cfprefsd
```

### Neovim に以前の設定が残っている

`nvim --clean` で標準設定の起動を確認する。通常起動との差がある場合は `~/.config/nvim` や `NVIM_APPNAME` 等を確認し、必要な内容を退避してから旧設定を整理する。Home Manager の switch は管理対象外の古い設定を削除しない。

### SSH 鍵を使えない

Bitwarden のログイン状態、SSH agent の有効化、`SSH_AUTH_SOCK` と `ssh-add -l` を確認する。新規導入で SSH をまだ使えない場合は、[セットアップ](setup.md)のリポジトリ取得を HTTPS と GitHub の認証で行う。
