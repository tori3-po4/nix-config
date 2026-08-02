# Chrome Remote Desktop で Windows を使う

Mac から実際の Windows PC に接続し、Windows 用ゲームをリモート実行する。PC版の Chrome Remote Desktop は独立したMacアプリではなく、Google Chrome上のWebアプリとして利用する。

## 構成

- 接続元: この Mac + Google Chrome
- 接続先: Windows PC + Chrome Remote Desktop Host
- 接続ページ: <https://remotedesktop.google.com/access>

Macを遠隔操作される側にしないため、このMacにはChrome Remote Desktop Hostをインストールしない。

## Mac側の準備

Google Chromeは `darwin/homebrew.nix` の `google-chrome` Caskで導入済みである。

1. Chromeで <https://remotedesktop.google.com/access> を開く。
2. Chrome右上のメニューから「キャスト、保存、共有」→「ページをアプリとしてインストール」を選ぶ。
3. アプリ名を `Chrome Remote Desktop` にしてインストールする。
4. Windows側と同じGoogleアカウントでログインする。

Webアプリを作成しなくても、同じURLをChromeで開けば接続できる。

## Windows側の準備

1. WindowsのChromeで <https://remotedesktop.google.com/access> を開く。
2. 「リモートアクセスの設定」からChrome Remote Desktop Hostをダウンロードしてインストールする。
3. PC名と6桁以上のPINを設定する。
4. Windowsの電源設定で、使用中にスリープへ入らないよう調整する。
5. ゲームをWindowsへインストールし、Windows上で一度直接起動して動作確認する。

PINはこのリポジトリやシェル設定へ保存しない。

## 接続する

1. MacでChrome Remote Desktop Webアプリを開く。
2. 「リモートアクセス」からWindows PCを選ぶ。
3. Windows側で設定したPINを入力する。
4. 終了時は画面横のメニューから「切断」を選ぶ。

ノベルゲームでは、全画面表示より最初はウィンドウ表示で確認すると、解像度やマウス位置の問題を切り分けやすい。音が聞こえない場合は、Windows側でゲームとChrome Remote Desktopの音量ミキサーを確認する。

## セキュリティ

- Googleアカウントでは2段階認証を有効にする。
- 推測しにくいPINを使用し、他サービスと使い回さない。
- 不要になったPCは接続ページのデバイス一覧からリモート接続を無効化する。
- 一時的に他人へ接続を許可する場合だけ、`/support` のワンタイムコードを使用する。

## 参考リンク

- [Chrome Remote Desktop](https://remotedesktop.google.com/access)
- [Google公式: 別のパソコンにアクセスする](https://support.google.com/chrome/answer/1649523)
- [Google公式: Webアプリを使用する](https://support.google.com/chrome/answer/9658361)
