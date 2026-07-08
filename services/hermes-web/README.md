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

## Search Quality

SearXNG quality depends mostly on enabled upstream engines. This stack keeps the
default engine set, then explicitly tunes general web search:

- enables and weights `brave`, `google cse`, `bing`, `duckduckgo`, and `qwant`
- disables `startpage` because it frequently returns parsing errors locally
- disables `mojeek` because this local setup gets access denied responses
- lowers `wikipedia` / `wikidata` weight so encyclopedic results do not dominate
- raises the request timeout from the default 2s to 4s globally, with 5s for
  main web engines

Check the currently enabled engines:

```bash
curl -s http://localhost:8888/config \
  | jq -r '.engines[] | select(.enabled) | [.name, (.categories|join(",")), .timeout] | @tsv'
```

If Hermes stops after a single query, that is agent behavior rather than a
SearXNG setting. Add a persistent instruction to `~/.hermes/SOUL.md`, for
example:

```text
For research or web-backed factual questions, run multiple targeted web_search
queries before answering. Use at least 2-4 distinct query phrasings unless the
answer is already directly known from a primary source. Search both Japanese and
English when that may improve coverage, then extract/open the most authoritative
results before concluding.
```

Firecrawl logs:

```bash
docker compose logs -f firecrawl-api
```

Stop:

```bash
docker compose down
```
