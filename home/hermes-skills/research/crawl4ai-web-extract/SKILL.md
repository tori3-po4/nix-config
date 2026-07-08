---
name: crawl4ai-web-extract
description: "Use the local Crawl4AI MCP server for URL extraction, JS-rendered pages, screenshots, PDFs, and crawls."
platforms: [linux, macos]
metadata:
  hermes:
    tags: [web, extract, crawl4ai, mcp, searxng, research]
    category: research
    requires_toolsets: [web]
---

# Crawl4AI Web Extract

## When To Use

Use this skill when a task needs reliable page content from URLs, especially
for JavaScript-rendered pages, pages that need screenshots or PDFs, or research
workflows that start with SearXNG search results.

Use SearXNG for discovery and Crawl4AI MCP tools for page retrieval. Crawl4AI
should not replace search ranking; it should fetch and render selected URLs
after search.

## Tool Choice

- Use `web_search` for discovery. It should route to SearXNG.
- Do not use built-in `web_extract` for Crawl4AI extraction in this setup.
  Crawl4AI is exposed through MCP only.
- Use MCP tool `crawl4ai:md` for normal markdown extraction from a URL.
- Use MCP tool `crawl4ai:html` when exact rendered HTML is needed.
- Use MCP tool `crawl4ai:screenshot` when visual page evidence is needed.
- Use MCP tool `crawl4ai:pdf` when the page needs to be preserved as PDF.
- Use MCP tool `crawl4ai:crawl` for bounded multi-page crawls.
- Use MCP tool `crawl4ai:execute_js` only when a page requires explicit
  interaction or JavaScript evaluation before extraction.
- Use MCP tool `crawl4ai:ask` for questions over previously fetched page
  content when that is supported by the running Crawl4AI server.

## Workflow

1. For factual research, run multiple targeted `web_search` queries unless the
   user supplied exact URLs.
2. Prefer official, primary, or otherwise authoritative URLs.
3. Extract the selected URLs with the Crawl4AI MCP tool that matches the needed
   output. Default to `crawl4ai:md`.
4. Cross-check important claims against more than one source when possible.
5. Report what was verified and distinguish direct source facts from
   inference.

## Verification

If the MCP tools appear unavailable, run:

```bash
hermes mcp test crawl4ai
hermes tools list
```

The Crawl4AI server should expose tools such as `md`, `html`, `screenshot`,
`pdf`, `execute_js`, `crawl`, and `ask`.
