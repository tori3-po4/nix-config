# Hermes Web Backends

Local Docker Compose stack for Hermes web tools:

- SearXNG search API: `http://localhost:8888`
- Crawl4AI extract API and MCP server: `http://localhost:11235`

Hermes uses SearXNG for `web_search`. Crawl4AI is exposed through MCP and the
`crawl4ai-web-extract` skill, not through built-in `web_extract`.

## Start

```bash
cd ~/nix-config/services/hermes-web
cp -n .env.example .env
docker compose up -d --remove-orphans
```

The first start pulls the SearXNG, Valkey, and Crawl4AI images.

## Hermes Config

`~/.hermes/config.yaml` is managed by chezmoi at
`~/.local/share/chezmoi/private_dot_hermes/private_config.yaml`:

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

`~/.hermes/.env`:

```dotenv
SEARXNG_URL=http://localhost:8888
CRAWL4AI_API_TOKEN=local-only-crawl4ai-change-me
```

Use the same `CRAWL4AI_API_TOKEN` value in `services/hermes-web/.env` and
`~/.hermes/.env`. Hermes reads the MCP URL from `mcp_servers.crawl4ai.url`.
Crawl4AI binds to container loopback when no token is set, so Docker port
publishing needs a token even for local-only use.

## Hermes TUI

Use these settings for the TUI profile:

- Web Search provider: `searxng`
- Web Extract provider: leave unset, or do not select Crawl4AI
- Plugins: do not enable `web/crawl4ai`
- MCP server: `crawl4ai` at `http://localhost:11235/mcp/sse`
- MCP transport: `sse`
- MCP auth header: `Authorization: Bearer ${CRAWL4AI_API_TOKEN}`
- Skill: `crawl4ai-web-extract`

Search remains SearXNG. Crawl4AI is only used through MCP tools from the skill.

The reliable way to apply the MCP setting is to edit the chezmoi source, run
`chezmoi apply`, keep `CRAWL4AI_API_TOKEN` in `~/.hermes/.env`, then restart the
TUI or run this slash command inside the TUI:

```text
/reload-mcp
```

Confirm from the TUI with:

```text
/tools list
```

From the terminal, the equivalent setup commands are:

```bash
hermes config set mcp_servers.crawl4ai.url http://localhost:11235/mcp/sse
hermes config set mcp_servers.crawl4ai.transport sse
hermes config set mcp_servers.crawl4ai.enabled true
hermes config set 'mcp_servers.crawl4ai.headers.Authorization' 'Bearer ${CRAWL4AI_API_TOKEN}'
hermes mcp test crawl4ai
```

Use `hermes mcp configure crawl4ai` if you want to enable or disable individual
Crawl4AI MCP tools.

The local skill is installed at
`~/.hermes/skills/research/crawl4ai-web-extract/SKILL.md`. It tells Hermes to
use SearXNG for discovery and the Crawl4AI MCP tools (`crawl4ai:md`,
`crawl4ai:html`, `crawl4ai:screenshot`, `crawl4ai:pdf`, `crawl4ai:crawl`,
`crawl4ai:execute_js`, `crawl4ai:ask`) for URL content.

## Check

```bash
curl 'http://localhost:8888/search?q=hermes&format=json' | jq '.results[0]'
curl -s http://localhost:11235/health
hermes plugins list --plain --no-bundled
hermes mcp list
hermes config check
```

After Crawl4AI is running, test the MCP connection:

```bash
hermes mcp test crawl4ai
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

Crawl4AI logs:

```bash
docker compose logs -f crawl4ai
```

Stop:

```bash
docker compose down
```
