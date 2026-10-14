# アプリ別の設定と使い方

[README に戻る](../README.md)

本体の導入先は[管理対象](configuration.md#管理対象)を参照。ここでは初回起動・操作・アプリ固有の設定を扱う。

- [Emacs](#emacs)
- [Lean 4 / Emacs](#lean-4--emacs)
- [VS Code の設定・拡張管理](#vs-code-の設定拡張管理)
- [Alacritty・tmux・Git](#alacrittytmuxgit)
- [Pi](#pi)
- [Kiwix と Wiki データ](#kiwix-と-wiki-データ)

## Emacs

macOS の本体は Homebrew の `emacs-plus-app`、Linux は GNU 公式ソースの URL とハッシュを固定した **Emacs 31.1 PGTK**。Linux では Native Compilation と Tree-sitter を有効にし、全 Elisp の事前ネイティブコンパイルのみ無効化している。

`home/emacs.nix` が `init.el` / `early-init.el` を `~/.config/emacs/` と互換用の `~/.emacs.d/` に配置する。パッケージは Emacs の `package.el` / `use-package` で取得する。GNU / NonGNU ELPA を優先し、Evil は NonGNU-devel、lsp-mode / lsp-pyright は MELPA を使う。初回はパッケージや文法を取得するネットワーク接続が必要。

| 用途 | 現在の設定 |
|---|---|
| 編集・キー案内 | Evil、標準 WhichKey（`M-SPC`、待ち時間 0.4 秒） |
| 補完 | Corfu（2文字・0.15秒、`.` で開始）、Vertico |
| LSP / 診断 | lsp-mode + Corfu CAPF + Flymake、yasnippet |
| Python / Nix | Pyright + Ruff / nixd |
| Astro / Web | web-mode + Astro / Tailwind / ESLint。Astro はプロジェクトの TypeScript を使用 |
| Dockerfile / YAML | dockerfile-ts-mode / yaml-ts-mode + 対応 LSP |
| 構文解析 | Emacs 標準の Tree-sitter 文法自動取得 |
| Git | Magit（`C-x g`）、diff-hl |
| 端末 | Eat（`M-x eat`）、zsh / bash のシェル連携 |
| 配色 | `modus-operandi-tinted` |
| Common Lisp / スペルチェック | SLIME + SBCL / aspell + Flyspell |

`early-init.el` で `LSP_USE_PLISTS=true` を設定し、起動後の GC 閾値を 64 MiB にする。古い hash-table 形式でコンパイルされた lsp-mode が残っている場合は、同じ環境変数で再コンパイルする。接続確認は `M-x lsp-describe-session`、個別プロジェクトの Nix 開発環境でサーバーを起動する場合は `M-x lsp-nix` を使う。

デーモンは macOS で `darwin/default.nix` の LaunchAgent `org.nixos.emacs`、Linux で `linux/default.nix` の `services.emacs` が GUI ログイン時に起動する。macOS は `/bin/zsh -lic` 経由で普段の PATH を読み、Linux のサービスには Bitwarden の `SSH_AUTH_SOCK` を明示する。

```bash
# 常駐デーモンに接続
emacsclient -c -n   # GUI
emacsclient -t      # TUI

# macOS: 状態・ログ
launchctl print "gui/$(id -u)/org.nixos.emacs"
tail -n 50 ~/Library/Logs/emacs-daemon.error.log

# Linux: 状態・ログ
systemctl --user status emacs
journalctl --user -u emacs -n 50
```

`Emacs.app` や `emacs -nw` の通常起動は独立したプロセスになる。デーモンの設定を読み直すときはバッファを保存してから再起動する。

```bash
# macOS: KeepAlive のため、一旦登録を解除してから再登録する
launchctl bootout "gui/$(id -u)/org.nixos.emacs"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/org.nixos.emacs.plist"

# Linux
systemctl --user restart emacs
```

## Lean 4 / Emacs

`home/default.nix` で `elan` を導入し、Lean本体とビルドツールLakeの版を管理する。
`lean` / `lake` コマンドはelanが提供するため、別の `lake` パッケージは追加しない。
Lean本体はNix storeの外の `~/.elan/toolchains` に取得される。

構成の[適用](maintenance.md#設定の反映)後、新しいターミナルで安定版の Lean を取得する。
macOS / Linux とも次を実行する。

```bash
elan default leanprover/lean4:stable
lean --version
lake --version
```

新しいプログラミング用プロジェクトの作成と実行:

```bash
mkdir -p ~/projects
cd ~/projects
lake new lean-playground exe
cd lean-playground
lake build
lake exe lean-playground
```

生成された `lean-toolchain` はGitに含め、プロジェクトで使うLeanの具体的な版を固定する。
既存プロジェクトでは、そのファイルに指定された版をelanが自動で取得・選択する。

Emacsを再起動し、`C-x C-f` でプロジェクト内の `Main.lean` を開く。
`lean4-mode` はEmacs標準の `package-vc` でGitHubから導入し、`.lean` に自動適用する。
初回の取得にはネットワーク接続が必要。
`lean4-mode` は直近リリースを取得する設定で、具体的なコミットは固定していない。Lean 用の操作は同モードが提供する。

| 操作 | キー / コマンド |
|------|----------------|
| 証明のゴール・エラー表示 | `C-c C-i` (`lean4-toggle-info`) |
| Lakeでビルド | `C-c C-p C-l` (`lean4-lake-build`) |
| importした依存を再読み込み | `C-c C-d` |
| Leanの版を確認 | `M-x lean4-show-version` |

例えば `Main.lean` に `#eval (List.range 5).map (fun n => n * n)` を追加すると、
評価結果は `[0, 1, 4, 9, 16]` になる。

参考: [Elan公式マニュアル](https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Managing-Toolchains-with-Elan/)、[lean4-modeの導入・操作](https://github.com/leanprover-community/lean4-mode)。

## VS Code の設定・拡張管理

本体は `home/default.nix`、拡張・C++ スニペットは `home/vscode.nix`、User 設定は `home/vscode-settings.json` で管理する。`mutableExtensionsDir = false` で、VS Code 本体と拡張の自動更新も無効化している。変更は Nix の宣言に追加して switch する。

Python / Jupyter、C/C++ / CMake、Java、Rust、LaTeX、Astro、Tailwind、ESLint、Nix、Remote SSH / Containers 等を宣言している。ESLint は `vscode-marketplace-release`、cpptools 本体は `pkgs.vscode-extensions`、その他は主に `vscode-marketplace` を使用する。具体的な版は `flake.lock` に依存する。

配色は Dark 2026、フォントは HackGen Console NF。保存時整形を有効にし、LaTeX は `tex-fmt` を使う。Prettier の VS Code 拡張は宣言していない。Web プロジェクトの TypeScript・ESLint・Tailwind 等の依存と Workspace 設定は各プロジェクトで管理する。

`home/vscode-settings.json` には `vim.*` の設定が残っているが、現在の拡張一覧には VSCodeVim が含まれず、Emacs 風のキー割り当ても宣言していない。

## Alacritty・tmux・Git

- `gitconfig`: ユーザー名・メール・デフォルトブランチ。既存のcredential helper無効化も維持
- `tmux.conf`, `latexmkrc`: `~/.tmux.conf` / `~/.latexmkrc` へ配置。Alacritty 本体・設定・テーマも macOS / Linux 共通で導入
- Alacritty: HackGen Console NF 16pt、130列×28行、不透明背景。macOS では左右 Option を Alt として使う。配色は `github_dark_high_contrast` を Home Manager で読み込む
- `TERM=xterm-256color` は Alacritty の `[env]` だけで設定し、SSH 先に専用 terminfo を要求しない。tmux 内は従来どおり `screen-256color`
- 行間は `font.offset.y=8`。Retina (2x)・16pt を基準にしているため、DPI や文字サイズを変えた場合は調整する
- SSH 接続設定はローカル管理、Neovim はデフォルト設定。秘密鍵は Bitwarden SSH agent 管理

設定項目は [Alacritty 公式ドキュメント](https://alacritty.org/config-alacritty.html) を参照。

## Pi

[Pi](https://github.com/earendil-works/pi) は公式 flake の `packages.<system>.default` を
`home/default.nix` の共通パッケージとして macOS / Linux に導入済み。

通常の switch で反映した後、初回のみ端末で認証・モデルを設定する。

```bash
pi             # 起動後に /login でプロバイダを選択（API キーによる認証も可能）
```

認証情報・設定・履歴は `~/.pi/agent/` のローカル管理とし、リポジトリには含めない。
本体と依存関係は `flake.lock` で固定する。更新は[依存関係の更新](maintenance.md#依存関係の更新)を参照。

## Kiwix と Wiki データ

本体は macOS では [Homebrew Cask `kiwix`](https://formulae.brew.sh/cask/kiwix)、Linux では
[Flathub `org.kiwix.desktop`](https://github.com/flathub/org.kiwix.desktop) で管理する。
通常の[設定の反映](maintenance.md#設定の反映)で導入される。
現時点では本体だけを宣言しており、Wiki データの自動ダウンロードは行わない。
[Kiwix Library](https://library.kiwix.org/) で言語・内容・容量を確認し、ZIM ファイルを選ぶ。
ZIM はオフライン閲覧用のスナップショットで、更新時は新しい版を取得する。

Wiki データも宣言的に管理できる。方法は次の2つ。

- **Nix store に固定する**: 日付入りの ZIM URL と SHA-256 を `pkgs.fetchurl` に指定し、
  Home Manager の `home.file` で閲覧用パスにリンクする。URL とハッシュを変更して更新する。
  旧世代が参照する ZIM も GC までは残るため、大容量の Wikipedia では更新時の空き容量に注意する。
  配布元が旧版を削除する場合に備え、長期の再取得には自分での保存・ミラーも必要になる。
- **Nix store の外に保存する**: 取得対象の URL・ハッシュ・保存先と同期コマンドを Nix で定義し、
  ZIM 本体は専用ディレクトリや外付け SSD に置く。大容量データ向けだが、ハッシュ検証、
  ダウンロード再開、旧版の扱いを同期処理側で実装する必要がある。

前者の設定例（未適用。`url` と `hash` は選んだ ZIM の実値に置き換える）：

```nix
# Home Manager モジュール内（pkgs を引数で受け取る）
home.file."Documents/Kiwix/wikipedia-ja.zim".source = pkgs.fetchurl {
  url = "https://download.kiwix.org/zim/wikipedia/<日付入りのファイル名>.zim";
  hash = "sha256-<ZIM の SHA-256 を base64 で記載>";
};
```

取得後は Kiwix でそのファイルを開く。ファイルの配置とアプリ内のライブラリ登録は別の操作になる。
Linux の Flatpak でこのリンクを直接参照させる場合は、保存先とリンク先 `/nix/store` の
読み取り権限を `linux/flatpak.nix` の Kiwix 用 override に追加する。
参照: [Nixpkgs の `fetchurl`](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-fetchers-fetchurl)。
