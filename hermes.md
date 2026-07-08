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
- **Hermes 設定**: `~/.local/share/chezmoi/private_dot_hermes/`。`~/.hermes/config.yaml`、
  `~/.hermes/SOUL.md`、`~/.hermes/skills/` は chezmoi で管理する。
- **モデルサーバ**: `darwin/lfm-server.nix`。`inputs.lfm2-agent`（`github:tori3-po4/LFM2.5_for_MLX`）
  を uv2nix でビルドした `lfm2-serve` を launchd で常駐（`:8080`）。
- **docker**: `home/default.nix` の `colima` / `docker-client` / `docker-compose`（podman 併用）。
- **モデルは必ずホスト常駐**: MLX は Apple GPU(Metal) 依存でコンテナ内では動かせない。
  docker は「コマンド実行の隔離」専用で、LLM 接続には使わない（だから `localhost` で届く）。
- **web backend**: `services/hermes-web/docker-compose.yml`。SearXNG を検索、
  Crawl4AI を URL 抽出に使うローカル compose stack。

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

### web backend (SearXNG + Crawl4AI)

```bash
cd ~/nix-config/services/hermes-web
cp -n .env.example .env
docker compose up -d
```

公開ポートはローカル限定:

- SearXNG: `http://localhost:8888`
- Crawl4AI: `http://localhost:11235`

Hermes から使う設定は chezmoi 側の
`~/.local/share/chezmoi/private_dot_hermes/private_config.yaml` で管理する。
実体としては `~/.hermes/config.yaml` に以下が入る。

```yaml
web:
  backend: searxng
  search_backend: searxng
  use_gateway: false

mcp_servers:
  crawl4ai:
    url: http://localhost:11235/mcp/sse
    transport: sse
    enabled: true
    headers:
      Authorization: "Bearer ${CRAWL4AI_API_TOKEN}"
```

`~/.hermes/.env` には以下を置く。`CRAWL4AI_API_TOKEN` は
`services/hermes-web/.env` と同じ値にする。Crawl4AI は token 未設定だと
コンテナ内 loopback にだけ bind するため、Docker のポート公開経由で使う今回の構成では token が必要。

```dotenv
SEARXNG_URL=http://localhost:8888
CRAWL4AI_API_TOKEN=local-only-crawl4ai-change-me
```

Hermes TUI では Web Search provider を `searxng` にする。Web Extract provider
は未設定、または Crawl4AI を選ばない。Plugins では `web/crawl4ai` を有効化しない。
MCP は `crawl4ai` / `http://localhost:11235/mcp/sse` / transport `sse` を使う。
MCP の header は `Authorization: Bearer ${CRAWL4AI_API_TOKEN}`。URL 抽出は
`crawl4ai-web-extract` skill から Crawl4AI MCP tools を使う。

TUI で反映するには、chezmoi source を編集して `chezmoi apply` し、
`~/.hermes/.env` に `CRAWL4AI_API_TOKEN` を置いてから TUI を再起動する。
起動中なら `/reload-mcp`、確認は `/tools list`。一時的に CLI で直接設定する場合は:

```bash
hermes config set mcp_servers.crawl4ai.url http://localhost:11235/mcp/sse
hermes config set mcp_servers.crawl4ai.transport sse
hermes config set mcp_servers.crawl4ai.enabled true
hermes config set 'mcp_servers.crawl4ai.headers.Authorization' 'Bearer ${CRAWL4AI_API_TOKEN}'
hermes mcp test crawl4ai
```

動作確認:

```bash
curl 'http://localhost:8888/search?q=hermes&format=json' | jq '.results[0]'
curl -s http://localhost:11235/health
hermes mcp list
hermes config check
```

検索品質:

- `services/hermes-web/searxng/settings.yml` で一般 Web 検索向けに
  `brave` / `google cse` / `bing` / `duckduckgo` / `qwant` を明示的に有効化し、
  `weight` と `timeout` を調整している。
- ローカル検証で `startpage` は parsing error、`mojeek` は access denied が出やすいため無効化。
- `wikipedia` / `wikidata` は一般検索の上位を占有しすぎないよう軽めの weight にする。
- SearXNG は「1つのクエリを複数検索エンジンに投げる」役割。Hermes が
  「複数の言い換えクエリを投げる」かどうかは agent 側の判断なので、必要なら
  `~/.hermes/SOUL.md` に以下のような恒久指示を追加する。

```text
For research or web-backed factual questions, run multiple targeted web_search
queries before answering. Use at least 2-4 distinct query phrasings unless the
answer is already directly known from a primary source. Search both Japanese and
English when that may improve coverage, then extract/open the most authoritative
results before concluding.
```

## 設定変更

### Hermes 設定（chezmoi）

`~/.hermes/config.yaml`、`~/.hermes/SOUL.md`、`~/.hermes/skills/` は chezmoi で管理する。
編集は source dir 側で行い、`chezmoi apply` で反映する。

```bash
chezmoi edit ~/.hermes/config.yaml
chezmoi edit ~/.hermes/SOUL.md
chezmoi edit ~/.hermes/skills/research/crawl4ai-web-extract/SKILL.md
chezmoi diff
chezmoi apply
```

`~/.hermes/.env` は token 類を含むため通常ファイルとしてローカルに置き、必要なら
chezmoi の encrypted/template 管理に切り替える。

- `model.default` は**配信モデル名と一致必須**（= `serve.py` の `DEFAULT_MODEL`
  `LiquidAI/LFM2.5-8B-A1B-MLX-4bit`）。量子化バリアントを変えるなら両方を揃える。
- `providers.local-llama.api` は `http://localhost:8080/v1`（末尾スラッシュ無し）。
- ローカルは認証不要だが `api_key` は空だと弾かれることがあるためダミー値を入れる。
- API キー等の秘密情報は Nix 管理外の `~/.hermes/.env` に置く。

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
| web search / Crawl4AI MCP が動かない | `cd ~/nix-config/services/hermes-web && docker compose ps`、`SEARXNG_URL`、`mcp_servers.crawl4ai.url`、`hermes mcp test crawl4ai` を確認 |
| 設定変更が反映されない | `~/.hermes/config.yaml` を確認。YAML 構文や Hermes 側の読み込みタイミングを疑う |
| `tool_calls` が返らない | LFM サーバ (`serve.py`) が pythonic パーサ用モンキーパッチ込みで起動しているか。`lfm2-serve` 経由なら適用済み |
| 初回起動が遅い | モデル DL(~4.5GB→`~/.cache/huggingface`) と Hermes の初回ビルドのため。2回目以降は速い |
| `'system' has been renamed...` 警告 | nixpkgs の非推奨警告。`pkgs.system`→`pkgs.stdenv.hostPlatform.system`。本リポジトリでは対応済み |

## 関連ファイル

- `flake.nix` … `hermes-agent` / `lfm2-agent` input
- `home/hermes.nix` … Hermes 本体のインストールのみ
- `~/.local/share/chezmoi/private_dot_hermes/` … Hermes config / SOUL / skills
- `darwin/lfm-server.nix` … LFM2.5 サーバの launchd 常駐
- `home/default.nix` … colima / docker-client / docker-compose
- `services/hermes-web/` … SearXNG + Crawl4AI のローカル web backend
- 上流: `github:NousResearch/hermes-agent`, `github:tori3-po4/LFM2.5_for_MLX`
