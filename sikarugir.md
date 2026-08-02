# Sikarugir で Windows ノベルゲームを動かす

この構成では、Sikarugir Creator 本体を nix-darwin + Homebrew で管理し、ゲームごとの Wine Wrapper は Sikarugir Creator で作成する。

Sikarugir は Wine を使って Windows アプリケーションを macOS の `.app` として実行するツールであり、仮想マシンではない。ゲームや DRM の方式によっては動作しない場合がある。

## 前提

- Apple Silicon Mac
- macOS 14 Sonoma 以降
- Rosetta 2
- 正規に入手したゲーム本体またはインストーラー

このリポジトリでは `nix-homebrew.enableRosetta = true` を設定済みだが、これは Intel Homebrew の prefix を準備する設定であり、Apple の Rosetta 2 自体をインストールするものではない。

## 初回セットアップ

### 1. Rosetta 2 をインストールする

Apple Silicon では Wine の x86_64 バイナリ実行に Rosetta 2 が必要になる。未導入の場合のみ実行する。

```bash
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

導入済みか確認する場合:

```bash
pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto
```

### 2. nix-darwin の設定を反映する

`darwin/homebrew.nix` には次の設定を宣言している。

```nix
homebrew = {
  taps = [
    "Sikarugir-App/sikarugir"
  ];

  casks = [
    {
      name = "Sikarugir-App/sikarugir/sikarugir";
      trusted = true;
    }
  ];
};
```

設定を反映する。

```bash
sudo darwin-rebuild switch --flake ~/nix-config --impure
```

Sikarugir は Homebrew 公式リポジトリ外の tap から取得する。設定では完全修飾した Cask 名を使っているため、nix-darwin は生成する Brewfile に次のような Cask 単位の trust を追加する。

```ruby
cask "Sikarugir-App/sikarugir/sikarugir", trusted: true
```

このため `darwin-rebuild` を使う通常の導入では、別途 `brew trust` を実行する必要はない。tap 全体ではなく、導入する Sikarugir Cask だけが activation 中の信頼対象になる。すでに `brew trust` で永続的に信頼済みでも、この設定と競合しない。

Homebrew コマンドで手動インストールする場合は nix-darwin の一時的な Cask trust が使われないため、公式の案内どおり事前に次を実行する。

```bash
brew trust --tap Sikarugir-App/sikarugir
brew install --cask Sikarugir-App/sikarugir/sikarugir
```

このリポジトリは `homebrew.onActivation.cleanup = "uninstall"` を使用している。Sikarugir を `darwin/homebrew.nix` から削除すると、次回の rebuild でアンインストール対象になる。

インストール確認:

```bash
brew list --cask | grep '^sikarugir$'
```

Finder の `/Applications` に `Sikarugir Creator.app` が作成される。

## ゲーム用 Wrapper の作成

ゲームごとに個別の Wrapper を作る。異なるゲームを同じ Wrapper にまとめない方が、エンジンや Winetricks の設定をゲームごとに変更しやすい。

1. `Sikarugir Creator` を起動する。
2. `Installed Engines` の `+` を押し、最新の安定版 Wine engine をダウンロードする。
3. `Wrapper Version` が未導入または更新可能なら、最新の template をダウンロードする。
4. 使用する engine を選び、`Create New Blank Wrapper` を押す。
5. Wrapper 名を `GameTitle` のような英数字で指定する。
6. 作成された `~/Applications/Sikarugir/GameTitle.app` を開く。
7. `Advanced` → `Tools` → `Winetricks` を開く。
8. `fakejapanese` を検索して実行する。
9. `Install Software` からゲームをインストールする。

インストーラーがある場合は `Choose Setup Executable`、展開済みのゲームフォルダーを取り込む場合は `Copy a Folder Inside` を使用する。最後に起動対象を尋ねられたら、設定ツールではなくゲーム本体の `.exe` を選択する。

Wrapper は通常、次の場所に作成される。

```text
~/Applications/Sikarugir/<Wrapper名>.app
```

## 日本語ノベルゲーム向けの調整

最初から多数のコンポーネントを導入せず、`fakejapanese` を設定した状態で一度起動し、症状に応じて変更する。

### 日本語が四角形になる

まず Winetricks の `fakejapanese` を導入する。これは MS Gothic などの Windows フォント名を、利用可能な日本語フォントへ置き換える。

一部の書体が不足する場合に限り、Winetricks の `cjkfonts` を追加する。

### Shift-JIS の文字が化ける

ゲームが古い Shift-JIS 前提の場合は、Finder から起動した Wine に日本語 locale が渡るよう、`darwin/default.nix` に次を追加する方法がある。

```nix
launchd.user.envVariables.LANG = "ja_JP.UTF-8";
```

これはすべてのユーザー GUI アプリケーションに影響するため、文字化けが発生した場合だけ設定する。反映後は Sikarugir と Wrapper を終了してから起動し直す。

### 画面が黒または白になる

Wrapper の描画設定で DXVK のオン・オフを切り替える。

- 古い DirectDraw 系ゲーム: WineD3D（DXVK オフ）から試す
- DirectX 9～11: DXVK を試す
- 新しい64ビット DirectX 11/12: DXMT または D3DMetal を試す

ノベルゲームのエンジンによって正解が異なるため、一つの設定をすべての Wrapper に適用しない。

### 音声再生中に停止する

Wrapper の同期設定で `msync` を有効化して再確認する。

### OP動画だけ再生されない

ゲームが要求する動画方式を確認したうえで、Winetricks の `lavfilters` や `quartz` を個別に試す。不要な codec や DLL を一括導入すると別の問題を起こすことがあるため、Wrapper のバックアップを作ってから変更する。

## Wrapper の再設定とバックアップ

作成済み Wrapper を再設定するには、Finder で `.app` を右クリックして「パッケージの内容を表示」を選び、内部の Sikarugir 設定アプリを起動する。

Wrapper 内にゲーム本体、レジストリ、追加 DLL、セーブデータが保存される場合がある。次のディレクトリをバックアップ対象にする。

```text
~/Applications/Sikarugir/
```

ゲームによっては `~/Documents` 側にセーブデータを作るため、実際の保存場所もゲームごとに確認する。

## 制限事項

- Windows 用 DRM、ディスク認証、ハードウェア依存ドライバーは動作しない場合がある。
- アップデーターやランチャーだけが動かず、ゲーム本体を直接指定すると動く場合がある。
- Sikarugir Creator の宣言管理はできるが、GUI で取得する Wine engine、template、ゲーム Wrapper の内容は Nix の管理対象外である。
- Wrapper を削除すると、その中に保存されたゲーム設定やセーブデータも失われる可能性がある。

## 参考リンク

- [Sikarugir 公式リポジトリ](https://github.com/Sikarugir-App/Sikarugir)
- [Sikarugir Homebrew tap](https://github.com/Sikarugir-App/homebrew-sikarugir)
- [Homebrew `trust` コマンド](https://docs.brew.sh/Manpage#trust-options-target)
- [Winetricks verbs](https://github.com/Winetricks/winetricks/blob/master/files/verbs/all.txt)
