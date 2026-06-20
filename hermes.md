# Hermes Agent + LFM2.5 運用メモ

Hermes Agent（Nous Research）を、ローカルの LFM2.5 (MLX) サーバをモデルに、
docker(colima) をコマンド実行サンドボックスにして動かすための運用手順。

## 構成

```
Hermes (host, nix管理) ──LLM(OpenAI互換)──▶ localhost:8080
   │                                         ▲ launchd: lfm2-serve (uv2nix package)
   └─ コマンド実行 ──▶ docker サンドボックス (colima = lima VM 内の dockerd)
```

- **Hermes 本体**: `home/hermes.nix`。`inputs.hermes-agent` の package を home-manager で導入。
- **モデルサーバ**: `darwin/lfm-server.nix`。`inputs.lfm2-agent`（`github:tori3-po4/LFM2.5_for_MLX`）
  を uv2nix でビルドした `lfm2-serve` を launchd で常駐（`:8080`）。
- **docker**: `home/default.nix` の `colima` / `docker-client` / `docker-compose`（podman 併用）。
- **モデルは必ずホスト常駐**: MLX は Apple GPU(Metal) 依存でコンテナ内では動かせない。
  docker は「コマンド実行の隔離」専用で、LLM 接続には使わない（だから `localhost` で届く）。

各コンポーネントの依存・バージョンは `uv.lock` / 各 flake の `flake.lock` に固定。

## 初回セットアップ

```bash
# 1) 反映（初回は Hermes の uv2nix/npm ビルドが重い: 数百MiB DL + 多数ビルド）
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# 2) docker daemon を起動（Apple Silicon は vz 推奨。マシン再起動ごとに必要）
colima start --vm-type vz

# 3) モデルサーバは launchd が自動常駐。初回はモデルDL(~4.5GB)で起動まで時間がかかる
curl -s localhost:8080/v1/models                 # モデルが返ればOK
tail -f ~/Library/Logs/lfm2-serve.log            # 進捗確認

# 4) Hermes 実行
hermes
```

> `--impure` は必須（`flake.nix` が `$HOME` を `getEnv` で読むため）。

## 日常運用

```bash
hermes                       # 起動
colima status                # docker VM が動いているか
curl -s localhost:8080/v1/models   # モデルサーバ生存確認
```

### モデルサーバ (launchd: `org.nixos.lfm2-serve`)

```bash
launchctl print gui/$(id -u)/org.nixos.lfm2-serve | head   # 状態
launchctl kickstart -k gui/$(id -u)/org.nixos.lfm2-serve   # 再起動
launchctl bootout  gui/$(id -u)/org.nixos.lfm2-serve       # 停止(rebuildで再登録)
tail -f ~/Library/Logs/lfm2-serve.log                       # 標準出力ログ
tail -f ~/Library/Logs/lfm2-serve.err.log                   # エラーログ
```

`KeepAlive=true` なので落ちても自動再起動し、ログイン時に自動起動する（常時 ~5GB RAM）。

### docker (colima)

```bash
colima start --vm-type vz    # 起動（再起動後など）
colima stop                  # 停止
docker ps                    # 動作確認（context は colima に自動切替）
```

## 設定変更

### モデル / エンドポイント（`~/.hermes/config.yaml`）

このファイルは **home-manager 管理（nix store への read-only symlink）**。
`hermes config set` やウィザードからの書き込みは効かない。変更は必ず
`home/hermes.nix` を編集 → `darwin-rebuild switch` し直す。

- `model.default` は**配信モデル名と一致必須**（= `serve.py` の `DEFAULT_MODEL`
  `LiquidAI/LFM2.5-8B-A1B-MLX-4bit`）。量子化バリアントを変えるなら両方を揃える。
- `base_url` は `http://localhost:8080/v1`（末尾スラッシュ無し）。
- ローカルは認証不要だが `api_key` は空だと弾かれることがあるためダミー値を入れる。
- API キー等の秘密情報は HM 管理外の `~/.hermes/.env` に手で置く。

### ポート番号を変える

`darwin/lfm-server.nix` の `--port 8080` と `home/hermes.nix` の `base_url` を両方変更。

### サンドボックスのイメージを変える

`home/hermes.nix` の `terminal.docker_image`（既定 `nikolaik/python-nodejs:python3.11-nodejs20`）。

## 更新

```bash
# Hermes 本体を更新
nix flake update hermes-agent --flake ~/nix-config
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# LFM サーバを更新（先に github:tori3-po4/LFM2.5_for_MLX を push してから）
nix flake update lfm2-agent --flake ~/nix-config
sudo darwin-rebuild switch --flake ~/nix-config#default --impure
```

LFM サーバの依存を変えるとき（`my-LFM2.5-agent` 側）:
`uv add ...` → `uv.lock` 更新 → commit/push → 上記 `nix flake update lfm2-agent`。
開発用 `.venv`（PyCharm）とサーバの Nix ビルドは同じ `uv.lock` 由来なので版がズレない。

## トラブルシュート

| 症状 | 対処 |
|---|---|
| Hermes がモデルに繋がらない | `curl localhost:8080/v1/models`、`~/Library/Logs/lfm2-serve.err.log` を確認。落ちていれば `launchctl kickstart -k ...` |
| docker backend が動かない | `colima status` で起動確認 → `colima start --vm-type vz`。`docker ps` が通るか |
| 設定変更が反映されない | `config.yaml` は HM 管理 read-only。`home/hermes.nix` を直して rebuild |
| `tool_calls` が返らない | LFM サーバ (`serve.py`) が pythonic パーサ用モンキーパッチ込みで起動しているか。`lfm2-serve` 経由なら適用済み |
| 初回起動が遅い | モデル DL(~4.5GB→`~/.cache/huggingface`) と Hermes の初回ビルドのため。2回目以降は速い |
| `'system' has been renamed...` 警告 | nixpkgs の非推奨警告。`pkgs.system`→`pkgs.stdenv.hostPlatform.system`。本リポジトリでは対応済み |

## 関連ファイル

- `flake.nix` … `hermes-agent` / `lfm2-agent` input
- `home/hermes.nix` … Hermes 本体 + `~/.hermes/config.yaml`
- `darwin/lfm-server.nix` … LFM2.5 サーバの launchd 常駐
- `home/default.nix` … colima / docker-client / docker-compose
- 上流: `github:NousResearch/hermes-agent`, `github:tori3-po4/LFM2.5_for_MLX`
