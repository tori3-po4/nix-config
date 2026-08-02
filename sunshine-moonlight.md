# Sunshine + Moonlight で Windows ゲームをMacから遊ぶ

Windows PCでゲームを実行し、オープンソースのSunshineで配信、MacのMoonlightで操作する。外出先からの接続にはTailscaleを使い、ルーターのポート開放やSunshineのUPnPは使用しない。

## 構成

- ホスト: Windows PC + [Sunshine](https://github.com/LizardByte/Sunshine)
- クライアント: このMac + [Moonlight](https://github.com/moonlight-stream/moonlight-qt)
- プライベートネットワーク: Tailscale

SunshineとMoonlightはGPL-3.0のオープンソースソフトウェアである。

## Mac側: Moonlightを導入する

MoonlightはHomebrewではなくnixpkgsの `moonlight-qt` を使用する。`home/default.nix` の `home.packages` に宣言済みである。

```nix
home.packages = with pkgs; [
  moonlight-qt
];
```

nix-darwin構成を反映する。

```bash
sudo darwin-rebuild switch --flake ~/nix-config --impure
```

この構成では `targets.darwin.copyApps.enable = true` により、Moonlightのアプリバンドルが `~/Applications/Home Manager Apps/` にコピーされ、SpotlightやLaunchpadから起動できる。

確認:

```bash
nix-store -q --references ~/.local/state/nix/profiles/home-manager/home-path | grep -i moonlight
```

## Windows側: Sunshineを導入する

### 1. 前提を確認する

- 現行版Sunshineが対応するWindows 11
- ハードウェア動画エンコードに対応したGPUを推奨
- WindowsとMacの両方を同じtailnetへ参加させる
- Windowsにはローカルログイン用のパスワードを設定する

WindowsのTailscaleを常時接続にする場合は、Tailscaleのタスクトレイメニューから `Run Unattended` を有効にする。共有PCや信頼できないPCでは有効にしない。

### 2. Sunshineをインストールする

1. [Sunshine Releases](https://github.com/LizardByte/Sunshine/releases) から最新のWindows用インストーラーを取得する。
2. インストーラーを実行し、サービスとしてインストールする。
3. スタートメニューからSunshineを開く。
4. ChromeまたはEdgeで `https://localhost:47990` を開く。
5. 接続先が `localhost` であることを確認したうえで、自己署名証明書の警告を進む。
6. Sunshine管理画面用のユーザー名と、使い回していない長いパスワードを作成する。

管理画面の認証情報は、このリポジトリやシェル設定へ保存しない。

### 3. 安全なネットワーク設定にする

Sunshine管理画面の `Configuration` → `Network` で次を確認する。

- `UPnP`: Disabled
- `Address Family`: IPv4
- `Origin Web UI Allowed`: PCまたはLAN。WANにはしない
- `Port`: 既定値 `47989`

ルーターでSunshine用ポートを開放しない。Tailscale経由でのみWindowsの `100.x.x.x` アドレスへ接続する。

Windows Defender Firewallの確認画面が出た場合は、パブリックネットワークには許可せず、Tailscale経由で疎通できる範囲に限定する。接続できない場合に限り、Sunshineの既定ポートがWindows Firewallで許可されているか確認する。

| 用途 | ポート |
|---|---|
| HTTPS | TCP 47984 |
| HTTP | TCP 47989 |
| 管理画面 | TCP 47990 |
| RTSP | TCP 48010 |
| 映像 | UDP 47998 |
| 制御 | UDP 47999 |
| 音声 | UDP 48000 |

管理画面の47990はWindows自身の `localhost` からだけ利用し、Macへ公開する必要はない。

### 4. Windowsデスクトップを登録する

Sunshine管理画面の `Applications` を開く。`Desktop` がなければ次の内容で追加する。

- Application Name: `Desktop`
- Command: 空欄
- Working Directory: 空欄

ゲームを個別登録する必要はない。まずDesktop配信でWindowsへ接続し、その中からゲームを起動する。

## MacとWindowsをペアリングする

1. WindowsのTailscale画面または管理コンソールで、Windows PCの `100.x.x.x` アドレスを確認する。
2. MacでMoonlightを起動する。
3. 右上のPC追加ボタンを押し、WindowsのTailscale IPを入力する。
4. 表示されたWindows PCを選ぶ。
5. Moonlightに表示されたPINを控える。
6. Windowsで `https://localhost:47990` を開き、Sunshineの `PIN` 画面へ入力する。
7. Moonlightに戻り、`Desktop` を選択する。

Windows PCが自動検出されなくても異常ではない。Tailscaleはブロードキャストを転送しないため、Tailscale IPを手動追加する。

## 最初の推奨設定

Moonlightの設定は、最初は次から試す。

- Resolution: 1920x1080
- Frame rate: 60 FPS
- Video bitrate: 10～20 Mbps
- Video codec: Automatic
- HDR: Off
- Audio: Stereo

安定動作を確認した後で、解像度やビットレートを上げる。ノベルゲームはウィンドウ表示で最初の起動確認を行う。

## 接続できない場合

1. 両端末でTailscaleが接続中か確認する。
2. MacからWindowsへ `tailscale ping <Windowsの端末名または100.x.x.x>` を実行する。
3. Windows上でSunshineサービスが実行中か確認する。
4. Windows自身で `https://localhost:47990` が開くか確認する。
5. Windows Defender FirewallでSunshineが遮断されていないか確認する。
6. MoonlightからWindowsのTailscale IPを削除し、もう一度手動追加する。

`tailscale ping` が `via DERP` でも通信内容は暗号化されるが、遅延が大きくなる。ゲーム配信では `direct` 接続が望ましい。

## 終了とセキュリティ

- Moonlightのセッションを終了してからWindowsをスリープまたはシャットダウンする。
- Windowsを常時稼働させる場合は、強いWindowsログインパスワードとTailscaleアカウントの2段階認証を使用する。
- 不要になったMoonlightクライアントはSunshine管理画面からペアリング解除する。
- Sunshine管理画面をインターネットへ公開しない。
- Tailscaleのtailnetへ不要な端末を参加させない。

## 参考リンク

- [Sunshine公式ドキュメント](https://docs.lizardbyte.dev/projects/sunshine/latest/)
- [Sunshine設定リファレンス](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html)
- [Moonlight公式リポジトリ](https://github.com/moonlight-stream/moonlight-qt)
- [Tailscale接続方式](https://tailscale.com/docs/reference/connection-types)
