# Phase 2 — Private web search via self-hosted SearXNG

**Date:** 2026-06-07
**Status:** Approved, pending implementation

## Goal

Give the local AI assistant private web search by self-hosting [SearXNG](https://github.com/searxng/searxng)
and wiring it into Open WebUI's built-in web-search feature. Chat prompts and history
never leave the Mac; the only outbound traffic is the search queries SearXNG forwards
to upstream engines, and search is opt-in per message.

## Non-goals (YAGNI)

- No Redis/Valkey (only needed for SearXNG's rate limiter — unnecessary for one local user).
- No host port published for SearXNG (internal-only; debug via container logs).
- No custom engine list beyond SearXNG's sensible defaults.

## Architecture

```
Ollama (native, :11434)
        ▲
        │ host.docker.internal
        │
┌───────┴───────────────── docker compose network ─────────────┐
│  open-webui (:3000 → host)        searxng (:8080, internal)   │
│        └──────── http://searxng:8080/search ──────┘           │
└───────────────────────────────────────────────────────────────┘
                                            │ outbound: search queries only
                                            ▼
                                   upstream search engines
```

Two containers on the default compose network. Open WebUI reaches SearXNG by service
name at `http://searxng:8080`. SearXNG publishes no host port.

## Components

### 1. `searxng` service (docker-compose.yml)
- Image: `searxng/searxng:latest`
- No `ports:` mapping (internal only).
- Bind-mount `./searxng:/etc/searxng:rw` for config.
- `restart: unless-stopped`.

### 2. `searxng/settings.yml`
Minimal config overriding the image defaults:
- `server.secret_key` — a generated random hex string (required by SearXNG to start).
- `search.formats: [html, json]` — JSON is **required** for Open WebUI's API calls and
  is **off by default** in SearXNG.
- `server.limiter: false` — the limiter needs Redis; disabled so the stack stays at two
  containers.

### 3. Open WebUI wiring (env vars on the existing `open-webui` service)
- `ENABLE_WEB_SEARCH=true`
- `WEB_SEARCH_ENGINE=searxng`
- `SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>`

(Open WebUI 0.9.6 uses these names; the older `RAG_WEB_SEARCH_*` / `ENABLE_RAG_WEB_SEARCH`
names were renamed in an earlier release.)

## Data flow

1. User toggles **Web Search** on a message in Open WebUI.
2. Open WebUI requests `http://searxng:8080/search?q=<query>&format=json`.
3. SearXNG queries upstream engines and returns aggregated JSON results.
4. Open WebUI fetches the result pages and feeds them to `gemma4-tuned` as RAG context.
5. The model answers with citations.

## Error handling / edge cases

- **SearXNG won't start without `secret_key`** — generate one in `settings.yml`.
- **Search returns no results / 403** — usually JSON format not enabled; verified by the
  `formats` setting.
- **Open WebUI can't reach SearXNG** — both must be on the same compose network; verify
  with an in-container curl to `http://searxng:8080`.

## Verification

1. `docker compose up -d`; both containers report healthy/running.
2. From inside open-webui: `curl 'http://searxng:8080/search?q=test&format=json'` returns
   JSON with a non-empty `results` array.
3. In the UI: enable Web Search, ask a current-events question, confirm the answer cites
   fetched web sources.

## Docs to update

- `README.md`: check off Phase 2 in the roadmap, add a "Using web search" usage note and
  a troubleshooting entry.
- `docker-compose.yml` header comment: reflect that SearXNG is now part of the stack.
