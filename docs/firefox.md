# Firefox の移行

[README に戻る](../README.md)

新しい端末への移行と、旧 Home Manager 構成を使っていた端末での管理解除の手順。

- [移行元で準備](#1-移行元で準備)
- [新しい macOS で復元](#2-新しい-macos-で復元)
- [新しい Linux で復元](#3-新しい-linuxflatpakで復元)
- [既存端末で Home Manager 管理を解除](#既存端末で-home-manager-管理を解除する一度だけ)

Nix構成ではFirefox本体の導入と更新だけを管理する。macOSはHomebrew Cask、LinuxはFlatpakを使い、プロファイルの作成・選択、設定、拡張機能はFirefox自身に任せる。プロファイル名や保存先、インストールIDをNixへ記録する必要はない。

端末間ではFirefox Syncの **アドオンと設定だけ** を同期する。従来どおり、Cookie、保存済みログイン、ログイン状態、履歴、セッション、サイトストレージは別マシンへ移行しない。

| 移行対象 | 移行方法 |
|---|---|
| Syncの対象となるFirefox設定 | Firefox Syncの「設定」を同期 |
| 同期されない設定・ツールバー配置・`about:config` | 必要なものだけ新しいマシンで手動設定 |
| Zotero Connector | 新しいマシンでZotero公式サイトから手動導入 |
| その他の拡張機能 | Firefox Syncの「アドオン」を同期し、不足分を手動導入 |
| 拡張機能固有の設定 | 拡張機能自身の同期機能またはエクスポート／インポート |
| Cookie、保存済みログイン、履歴、セッション等 | 移行しない |

Syncはすべての設定を複製するものではない。同期対象は[Mozilla公式ヘルプ](https://support.mozilla.org/en-US/kb/sync-custom-preferences)を参照する。キャッシュ容量やプロセス数などは通常Firefoxの既定値を使い、必要が生じた端末だけで調整する。

## 1. 移行元で準備

1. FirefoxのSync設定で **アドオンと設定だけ** を有効にする。パスワード、履歴、開いているタブ、ブックマーク、住所、支払い方法等は無効にする。[同期対象の変更方法](https://support.mozilla.org/en-US/kb/how-do-i-choose-what-information-sync-firefox)を参照。
2. 「アドオンとテーマ」で使用中の拡張機能を確認し、同期されない設定やツールバー配置のうち、再現したいものを控える。
3. 拡張機能固有の設定が必要なら、それぞれの拡張機能が提供する同期機能を有効にするか、設定をエクスポートする。Firefox Syncで拡張機能本体が復元されても、内部のデータまで必ず同期されるとは限らない。

## 2. 新しい macOS で復元

1. [macOS のセットアップ](setup.md#macos)を実行し、Homebrew版Firefoxを導入する。
2. `/Applications/Firefox.app` を起動する。初回プロファイルはFirefoxが作成する。
3. 移行元と同じMozillaアカウントへログインし、Syncは **アドオンと設定だけ** を有効にする。
4. Zotero公式サイトからZotero Connectorを導入し、Zoteroとの接続を確認する。
5. 不足している拡張機能と必要な設定だけを手動で追加する。エクスポートした拡張機能の設定があればインポートする。各サービスへのログインは新しいマシンでやり直す。

> 別マシンへの移行では `~/Library/Application Support/Firefox` 全体をコピーしない。Cookieやログイン状態などを持ち込まず、Firefox自身が新しいプロファイルを作成する。

## 3. 新しい Linux（Flatpak）で復元

1. [Fedora など dnf 系 Linux](setup.md#linux) の手順でFlatpak本体、desktop portal、Nix、Home Manager構成を導入する。Flathub remoteとユーザ用アプリは `nix-flatpak` が管理する。
2. `private/user.nix` の `system` がLinuxのCPUに合う `x86_64-linux` または `aarch64-linux` であることを確認し、構成を適用する。

   ```bash
   home-manager switch --flake ~/nix-config#default --impure
   ```

3. `flatpak run org.mozilla.firefox` で起動し、macOSと同様にSyncとZotero Connectorを設定する。

プロファイルはFlatpakの標準領域 `~/.var/app/org.mozilla.firefox/.mozilla/firefox/` にFirefox自身が作成する（[Mozillaの移行案内](https://support.mozilla.org/en-US/kb/install-firefox-linux#w_data-migration)）。ホストの `~/.mozilla/firefox` や `/nix/store` へアクセスする専用overrideは使わない。

## 既存端末で Home Manager 管理を解除する（一度だけ）

この手順は、以前の `home/firefox.nix` を適用済みの端末だけで行う。同じ端末の既存データを引き継ぐための手順であり、上記の別マシンへの移行とは異なる。**最初にFirefoxを完全に終了し、作業が終わるまで起動しない。**

**macOS**

1. `~/Library/Application Support/Firefox` をバックアップする。
2. `profiles.ini` がHome Managerへのシンボリックリンクなら、内容を保った書き込み可能な通常ファイルへ置き換える。これにより、次のswitchでも既存プロファイルの登録が残る。

   ```bash
   (
     set -eu
     firefox_registry="$HOME/Library/Application Support/Firefox/profiles.ini"
     if [ -L "$firefox_registry" ]; then
       firefox_registry_copy=$(mktemp "${firefox_registry}.XXXXXX")
       cp -L "$firefox_registry" "$firefox_registry_copy"
       chmod u+w "$firefox_registry_copy"
       mv -f "$firefox_registry_copy" "$firefox_registry"
     fi
   )
   ```

3. `sudo darwin-rebuild switch --flake ~/nix-config#default --impure` を実行する。旧 `Profiles/default/user.js` の管理リンクはHome Managerが削除する。`profiles.ini` の削除をスキップしたという警告は、手順2で通常ファイルにしたためで正常。
4. Firefoxを起動し、既存の設定や拡張機能を確認する。プロファイルが選ばれない場合は `about:profiles` から既存の `Profiles/default` を使うプロファイルを登録し、既定にする。インストールIDの手動編集は不要。

**Linux（Flatpak）**

1. ホストの `~/.mozilla/firefox` と、存在する場合は `~/.var/app/org.mozilla.firefox/.mozilla/firefox` をバックアップする。
2. 旧構成で使っていた `~/.mozilla/firefox` の内容を、Flatpakの標準領域 `~/.var/app/org.mozilla.firefox/.mozilla/firefox` へコピーする。コピー先が既にある場合は別名で退避してから行い、異なるプロファイル同士を混ぜない。
3. コピー先の `profiles.ini` はリンク先の内容を持つ書き込み可能な通常ファイルにする。コピーされた `default/user.js` は `user.js.disabled` に改名して、旧設定の強制適用を止める。元の `~/.mozilla/firefox` は確認が済むまで残す。
4. `home-manager switch --flake ~/nix-config#default --impure` を実行する。旧管理ファイルのリンクと、nix-flatpakが管理していたFirefox専用overrideが解除される。
5. `flatpak run org.mozilla.firefox` で通常起動を確認する。プロファイルが選ばれない場合は `about:profiles` で引き継いだプロファイルを既定にする。Flatpak内の表示パスは `~/.mozilla/firefox` でも、ホスト側の実体は手順2の標準領域にある。

**管理解除は設定値の初期化ではない。** `user.js` を外しても以前の値は `prefs.js` に残るため、既存端末では必要に応じてFirefoxの設定画面や `about:config` で変更・リセットする。プロファイル全体や `prefs.js` を削除する必要はない。設定ファイルの役割は[Mozillaの仕様](https://firefox-source-docs.mozilla.org/modules/libpref/index.html)を参照。
