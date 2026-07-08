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
  `~/.hermes/config.yaml` は初回だけ通常ファイルとして作成し、以降は Hermes や手動編集から更新する。
- **モデルサーバ**: `darwin/lfm-server.nix`。`inputs.lfm2-agent`（`github:tori3-po4/LFM2.5_for_MLX`）
  を uv2nix でビルドした `lfm2-serve` を launchd で常駐（`:8080`）。
- **docker**: `home/default.nix` の `colima` / `docker-client` / `docker-compose`（podman 併用）。
- **モデルは必ずホスト常駐**: MLX は Apple GPU(Metal) 依存でコンテナ内では動かせない。
  docker は「コマンド実行の隔離」専用で、LLM 接続には使わない（だから `localhost` で届く）。
- **web backend**: `services/hermes-web/docker-compose.yml`。SearXNG を検索、
  Firecrawl を URL 抽出に使うローカル compose stack。

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

### web backend (SearXNG + Firecrawl)

```bash
cd ~/nix-config/services/hermes-web
cp -n .env.example .env
docker compose up -d
```

公開ポートはローカル限定:

- SearXNG: `http://localhost:8888`
- Firecrawl: `http://localhost:3002`

Hermes から使うには `~/.hermes/config.yaml` の `web` を以下にする。

```yaml
web:
  backend: firecrawl
  search_backend: searxng
  extract_backend: firecrawl
  use_gateway: false
```

`~/.hermes/.env` には以下を置く。Firecrawl は
`USE_DB_AUTHENTICATION=false` のローカル self-host なので API key は不要。

```dotenv
SEARXNG_URL=http://localhost:8888
FIRECRAWL_API_URL=http://localhost:3002
```

動作確認:

```bash
curl 'http://localhost:8888/search?q=hermes&format=json' | jq '.results[0]'
curl -s http://localhost:3002 | head
hermes config check
```

## 設定変更

### モデル / エンドポイント（`~/.hermes/config.yaml`）

このファイルは **通常ファイル**。Home Manager は初回作成と旧 read-only symlink からの
実ファイル移行だけ行い、既存ファイルの内容は上書きしない。`hermes config set` や
`hermes model` ウィザード、手動編集で直接変更できる。

- `model.default` は**配信モデル名と一致必須**（= `serve.py` の `DEFAULT_MODEL`
  `LiquidAI/LFM2.5-8B-A1B-MLX-4bit`）。量子化バリアントを変えるなら両方を揃える。
- `providers.local-llama.api` は `http://localhost:8080/v1`（末尾スラッシュ無し）。
- ローカルは認証不要だが `api_key` は空だと弾かれることがあるためダミー値を入れる。
- API キー等の秘密情報は HM 管理外の `~/.hermes/.env` に手で置く。

### ポート番号を変える

`darwin/lfm-server.nix` の `--port 8080` と `~/.hermes/config.yaml` の provider URL を両方変更。

### サンドボックスのイメージを変える

`~/.hermes/config.yaml` の `terminal.docker_image`（既定 `ubuntu:24.04`）。
Docker Official Image の base OS なので、Python/Node 等が必要な場合は sandbox 内で
`apt update && apt install ...` する。

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
| web search/extract が動かない | `cd ~/nix-config/services/hermes-web && docker compose ps`、`SEARXNG_URL` / `FIRECRAWL_API_URL`、`web.search_backend` / `web.extract_backend` を確認 |
| 設定変更が反映されない | `~/.hermes/config.yaml` を確認。YAML 構文や Hermes 側の読み込みタイミングを疑う |
| `tool_calls` が返らない | LFM サーバ (`serve.py`) が pythonic パーサ用モンキーパッチ込みで起動しているか。`lfm2-serve` 経由なら適用済み |
| 初回起動が遅い | モデル DL(~4.5GB→`~/.cache/huggingface`) と Hermes の初回ビルドのため。2回目以降は速い |
| `'system' has been renamed...` 警告 | nixpkgs の非推奨警告。`pkgs.system`→`pkgs.stdenv.hostPlatform.system`。本リポジトリでは対応済み |

## 関連ファイル

- `flake.nix` … `hermes-agent` / `lfm2-agent` input
- `home/hermes.nix` … Hermes 本体 + `~/.hermes/config.yaml` の初期値
- `darwin/lfm-server.nix` … LFM2.5 サーバの launchd 常駐
- `home/default.nix` … colima / docker-client / docker-compose
- `services/hermes-web/` … SearXNG + Firecrawl のローカル web backend
- 上流: `github:NousResearch/hermes-agent`, `github:tori3-po4/LFM2.5_for_MLX`
