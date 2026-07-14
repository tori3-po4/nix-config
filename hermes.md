# Hermes Agent + ローカルLLM 運用メモ

Hermes Agent(Nous Research)の運用手順。モデルはデフォルトで OpenAI Codex backend
(`gpt-5.5`)を使い、ローカルモデルは llama.cpp サーバ(router mode)を provider
として併用する。コマンド実行サンドボックスは Docker Desktop。

## 構成

```
Hermes (host, nix管理)
   ├─ LLM(デフォルト) ──▶ openai-codex provider (gpt-5.5)
   ├─ LLM(ローカル) ────▶ localhost:8080  llama.cpp router (launchd 常駐, darwin/llm.nix)
   ├─ コマンド実行 ─────▶ docker サンドボックス (Docker Desktop)
   └─ web tools ───────▶ ~/devs/hermes-web の compose stack
                          SearXNG :8888 / Firecrawl :3002 / pipeline(MCP) :8100
```

- **Hermes 本体**: `home/hermes.nix`。`inputs.hermes-agent` の package を home-manager で導入。
- **Hermes 設定**: `~/.local/share/chezmoi/private_dot_hermes/`。`~/.hermes/config.yaml` と
  `~/.hermes/SOUL.md` は chezmoi で管理する。
- **ローカルモデルサーバ**: `darwin/llm.nix`。llama.cpp の OpenAI 互換サーバを
  **router mode** で launchd 常駐(`127.0.0.1:8080`)。複数の GGUF モデルを preset に登録し、
  リクエストされたモデルを自動ロード・アイドル 300 秒で unload する(`--models-max 1`)。
  KV cache は q8_0。Web UI はビルド時に無効化(flake.nix の `llamaCppNoUiOverlay`)。
- **登録モデル** (すべて Hugging Face から自動DL、`~/.cache/llama.cpp` にキャッシュ):
  LFM2.5-8B-A1B (既定) / LFM2.5-1.2B-Instruct / gemma-4-E2B / gemma-4-E4B /
  granite-4.1-8b / gemma-4-12B-QAT / VibeThinker-3B
- **docker**: daemon は Docker Desktop(cask)。CLI は nix の `docker-client` / `docker-compose`。
  Hermes の terminal backend は docker 前提(podman は未対応)。
- **web backend**: `~/devs/hermes-web/`(nix-config 外のローカルリポジトリ)。
  SearXNG(検索)+ Firecrawl self-host(抽出)+ 検索パイプライン(search→scrape→rank を
  1コールで行う MCP サーバ、`:8100`)の compose stack。

## 初回セットアップ

```bash
# 1) 反映 (--impure は必須: flake.nix が $HOME を getEnv で読むため)
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# 2) Docker Desktop を起動 (メニューバーから常駐させる)
docker ps    # 通ればOK

# 3) ローカルモデルサーバは launchd が自動常駐 (router mode なのでモデルは要求時にDL/ロード)
curl -s localhost:8080/v1/models | jq '.data[].id'   # 登録モデル一覧が返ればOK
tail -f ~/Library/Logs/llama-server-lfm25.log         # 進捗確認

# 4) web backend を起動
cd ~/devs/hermes-web
docker compose up -d --remove-orphans

# 5) Hermes 実行
hermes
```

## 日常運用

```bash
hermes                                  # 起動
docker ps                               # docker daemon 生存確認
curl -s localhost:8080/v1/models        # ローカルモデルサーバ生存確認
```

### ローカルモデルサーバ (launchd: `org.nixos.llama-server-lfm25`)

```bash
launchctl print gui/$(id -u)/org.nixos.llama-server-lfm25 | head   # 状態
launchctl kickstart -k gui/$(id -u)/org.nixos.llama-server-lfm25   # 再起動
launchctl bootout  gui/$(id -u)/org.nixos.llama-server-lfm25       # 停止(rebuildで再登録)
tail -f ~/Library/Logs/llama-server-lfm25.log                       # 標準出力ログ
tail -f ~/Library/Logs/llama-server-lfm25.err.log                   # エラーログ
```

`KeepAlive=true` なので落ちても自動再起動し、ログイン時に自動起動する。
router mode + idle unload のため、モデル未使用時の常駐メモリは小さい。

### web backend (SearXNG + Firecrawl + pipeline)

```bash
cd ~/devs/hermes-web
cp -n .env.example .env      # 初回のみ。メモリ調整も .env で行う
docker compose up -d --remove-orphans
```

公開ポートはローカル限定:

- SearXNG: `http://localhost:8888`
- Firecrawl: `http://localhost:3002`
- 検索パイプライン (MCP): `http://localhost:8100/mcp`

パイプラインは `query → SearXNG → Firecrawl scrape → BM25 → embedding →
cross-encoder rerank → 上位チャンク` を 1 リクエストで返す。Hermes からは
`mcp_servers.web-research` として登録している。従来の `web_search` +
`web_extract` も SearXNG / Firecrawl backend で使える。

Hermes 側の設定(chezmoi 管理の `~/.hermes/config.yaml`)は以下。

```yaml
web:
  backend: searxng
  search_backend: searxng
  extract_backend: firecrawl
  use_gateway: false

plugins:
  enabled: []
  disabled:
    - web/crawl4ai

mcp_servers:
  web-research:
    url: http://localhost:8100/mcp
```

`~/.hermes/.env` には以下を置く。Firecrawl はローカル self-host なので API key 不要。

```dotenv
SEARXNG_URL=http://localhost:8888
FIRECRAWL_API_URL=http://localhost:3002
```

動作確認:

```bash
curl 'http://localhost:8888/search?q=hermes&format=json' | jq '.results[0]'
curl -s http://localhost:3002 | head
hermes plugins list --plain --no-bundled
hermes config check
```

検索品質:

- `~/devs/hermes-web/searxng/settings.yml` で一般 Web 検索向けにエンジンの
  有効化と `weight` / `timeout` を調整している。
- SearXNG は「1つのクエリを複数検索エンジンに投げる」役割。複数の言い換え
  クエリを投げるかどうかは agent 側の判断なので、必要なら `~/.hermes/SOUL.md`
  に恒久指示を書く。

## 設定変更

### Hermes 設定(chezmoi)

`~/.hermes/config.yaml`、`~/.hermes/SOUL.md` は chezmoi で管理する。
編集は source dir 側で行い、`chezmoi apply` で反映する。

```bash
chezmoi edit ~/.hermes/config.yaml
chezmoi edit ~/.hermes/SOUL.md
chezmoi diff
chezmoi apply
```

- `model.default` は現在 `gpt-5.5`(provider: `openai-codex`)。
- ローカルモデルを使うときは provider `local-llama`(`http://localhost:8080/v1`、
  末尾スラッシュ無し)。`models:` に列挙した名前は **`darwin/llm.nix` の router preset の
  モデル名と一致必須**。router がその名前で自動ロードする。
- ローカルは認証不要だが `api_key` は空だと弾かれることがあるためダミー値を入れる。
- API キー等の秘密情報は Nix / chezmoi 管理外の `~/.hermes/.env` に置く。

### ローカルモデルを追加/変更する

`darwin/llm.nix` の router preset(`llama-router-models.ini`)にエントリを追加し、
`~/.hermes/config.yaml` の `providers.local-llama.models` にも同じ名前を追加して
rebuild + `chezmoi apply`。

### ポート番号を変える

`darwin/llm.nix` の `--port 8080` と `~/.hermes/config.yaml` の provider URL を両方変更。

### サンドボックスのイメージを変える

`~/.hermes/config.yaml` の `terminal.docker_image`(既定 `ubuntu:24.04`)。
Docker Official Image の base OS なので、Python/Node 等が必要な場合は sandbox 内で
`apt update && apt install ...` する。

## 更新

```bash
# Hermes 本体を更新
nix flake update hermes-agent --flake ~/nix-config
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# llama.cpp を更新 (nixpkgs ごと)
nix flake update nixpkgs --flake ~/nix-config
nix build ~/nix-config#darwinConfigurations.default.system --impure --no-link  # 事前確認
sudo darwin-rebuild switch --flake ~/nix-config#default --impure

# web backend を更新
cd ~/devs/hermes-web
docker compose pull && docker compose up -d --build --remove-orphans
```

## トラブルシュート

| 症状 | 対処 |
|---|---|
| Hermes がローカルモデルに繋がらない | `curl localhost:8080/v1/models`、`~/Library/Logs/llama-server-lfm25.err.log` を確認。落ちていれば `launchctl kickstart -k ...` |
| docker backend が動かない | Docker Desktop が起動しているか確認 → `docker ps` が通るか |
| web search / web_extract / web-research が動かない | `cd ~/devs/hermes-web && docker compose ps`、`SEARXNG_URL`、`FIRECRAWL_API_URL`、`web.extract_backend`、`plugins.disabled`、`curl -s http://localhost:3002 \| head` を確認 |
| 設定変更が反映されない | chezmoi source を編集しただけで `chezmoi apply` を忘れていないか。`~/.hermes/config.yaml` の実体を確認 |
| ローカルモデルの初回応答が遅い | router がモデルを Hugging Face から DL / ロードしているため。`llama-server-lfm25.log` で進捗確認。2回目以降は速い |
| モデル名エラー | `config.yaml` の `models:` と `darwin/llm.nix` の preset 名が一致しているか確認 |

## 関連ファイル

- `flake.nix` … `hermes-agent` input、`llamaCppNoUiOverlay`
- `home/hermes.nix` … Hermes 本体のインストールのみ
- `darwin/llm.nix` … llama.cpp サーバ(router mode)の launchd 常駐
- `~/.local/share/chezmoi/private_dot_hermes/` … Hermes config / SOUL
- `home/default.nix` … docker-client / docker-compose / llama-cpp / lmstudio
- `darwin/homebrew.nix` … docker-desktop cask
- `~/devs/hermes-web/` … SearXNG + Firecrawl + 検索パイプラインの compose stack
- 上流: `github:NousResearch/hermes-agent`
