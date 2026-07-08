# Hermes Web Backends

Local Docker Compose stack for Hermes web tools:

- SearXNG search API: `http://localhost:8888`
- Firecrawl self-hosted API: `http://localhost:3002`

Hermes should use SearXNG for `web_search` and Firecrawl for `web_extract`.

## Start

```bash
cd ~/nix-config/services/hermes-web
cp -n .env.example .env
docker compose up -d
```

The first start pulls several images and can take a while.

## Hermes Config

`~/.hermes/config.yaml`:

```yaml
web:
  backend: firecrawl
  search_backend: searxng
  extract_backend: firecrawl
  use_gateway: false
```

`~/.hermes/.env`:

```dotenv
SEARXNG_URL=http://localhost:8888
FIRECRAWL_API_URL=http://localhost:3002
```

No `FIRECRAWL_API_KEY` is needed while Firecrawl runs with
`USE_DB_AUTHENTICATION=false`.

## Check

```bash
curl 'http://localhost:8888/search?q=hermes&format=json' | jq '.results[0]'
curl -s http://localhost:3002 | head
hermes config check
```

Firecrawl logs:

```bash
docker compose logs -f firecrawl-api
```

Stop:

```bash
docker compose down
```
