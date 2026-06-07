# Phase 2 — SearXNG Web Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add private web search to the local assistant by self-hosting SearXNG and wiring it into Open WebUI's built-in web-search feature.

**Architecture:** A second container (`searxng`) joins the existing compose stack on the default network. Open WebUI reaches it internally at `http://searxng:8080`; SearXNG publishes no host port. SearXNG runs without Redis (limiter disabled) and exposes a JSON API that Open WebUI calls when the user toggles web search on a message.

**Tech Stack:** Docker Compose, SearXNG (`searxng/searxng:latest`), Open WebUI 0.9.6.

> **Note — this is infra/config, not unit-testable code.** There is no test runner. Each task's verification step is a real command (or UI action) with expected output. Treat a verification that doesn't match its "Expected" as a failure to debug before moving on.

---

### Task 1: Create SearXNG config

**Files:**
- Create: `searxng/settings.yml`

- [ ] **Step 1: Generate a secret key and write the config**

Generate the key, then create the file with it substituted in. Run from the repo root:

```bash
mkdir -p searxng
SECRET=$(openssl rand -hex 32)
cat > searxng/settings.yml <<EOF
# Minimal SearXNG config for loca-gemma Phase 2.
# Overrides the image defaults: enables the JSON API (required by Open WebUI),
# disables the Redis-backed rate limiter (single local user), sets a secret key.
use_default_settings: true

server:
  secret_key: "${SECRET}"
  limiter: false
  image_proxy: true

search:
  # 'json' is OFF by default in SearXNG and is REQUIRED for Open WebUI's API calls.
  formats:
    - html
    - json
EOF
echo "wrote searxng/settings.yml"
```

- [ ] **Step 2: Verify the file is valid YAML and has the key filled in**

Run:
```bash
grep -q 'secret_key: ""' searxng/settings.yml && echo "FAIL: empty secret_key" || echo "OK: secret_key set"
python3 -c "import yaml,sys; yaml.safe_load(open('searxng/settings.yml')); print('OK: valid YAML')"
```
Expected:
```
OK: secret_key set
OK: valid YAML
```

- [ ] **Step 3: Commit**

```bash
git add searxng/settings.yml
git commit -m "feat: add SearXNG settings (JSON API on, limiter off)"
```

> Note: `searxng/settings.yml` contains a generated secret. It's fine to commit for a
> personal local stack; if this repo ever goes public, rotate the key.

---

### Task 2: Add the SearXNG service and wire Open WebUI

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add web-search env vars to the `open-webui` service**

In `docker-compose.yml`, under `services.open-webui.environment`, after the `WEBUI_AUTH=true` line, add:

```yaml
      # Phase 2: private web search via the searxng service (internal network).
      - ENABLE_WEB_SEARCH=true
      - WEB_SEARCH_ENGINE=searxng
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
```

- [ ] **Step 2: Add the `searxng` service**

In `docker-compose.yml`, after the entire `open-webui` service block and before the top-level `volumes:` key, add:

```yaml
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    # No host port published — only open-webui reaches it, over the compose network.
    volumes:
      - ./searxng:/etc/searxng:rw
    restart: unless-stopped
```

- [ ] **Step 3: Update the compose header comment**

Replace the line:
```
# Web search (SearXNG) and other services get added in later phases.
```
with:
```
# Phase 2 adds a searxng service for private web search. It has no published host
# port — Open WebUI reaches it internally at http://searxng:8080.
```

- [ ] **Step 4: Verify compose config parses and resolves both services**

Run:
```bash
docker compose config --services
```
Expected (order may vary):
```
open-webui
searxng
```

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add searxng service and wire Open WebUI web search"
```

---

### Task 3: Bring up the stack and verify connectivity

**Files:** none (runtime verification)

- [ ] **Step 1: Start the stack**

Run:
```bash
docker compose up -d
```
Expected: both `open-webui` and `searxng` containers created/started, no errors.

- [ ] **Step 2: Confirm both containers are running**

Run:
```bash
docker compose ps
```
Expected: `open-webui` and `searxng` both show state `running` (open-webui `healthy`).

- [ ] **Step 3: Check SearXNG started cleanly**

Run:
```bash
docker compose logs searxng | grep -iE "error|secret_key|listening" | tail -20
```
Expected: a "listening" line; **no** "secret_key" warning and no startup errors.

- [ ] **Step 4: Verify the JSON API from inside the Open WebUI container**

This proves both the network path open-webui→searxng AND that JSON is enabled.
Run:
```bash
docker exec open-webui sh -c \
  "curl -s 'http://searxng:8080/search?q=anthropic&format=json' | head -c 200"
```
Expected: a JSON object beginning `{"query": "anthropic", ... "results": [...`.
If you get a 403 / "Forbidden" / HTML, the `formats` setting didn't take — recheck Task 1.

---

### Task 4: Verify end-to-end in the UI

**Files:** none (manual verification)

- [ ] **Step 1: Run a web search in Open WebUI**

1. Open http://localhost:3000 and sign in.
2. Select the `gemma4-tuned` model.
3. Toggle **Web Search** on (the globe / "+" web-search control in the message bar).
4. Ask a current question, e.g. *"What's the latest stable Open WebUI release?"*

Expected: the response includes cited web sources (citation chips/links), confirming
SearXNG results flowed into the model context.

- [ ] **Step 2: Sanity-check no host port leaked**

Run:
```bash
docker compose ps searxng
```
Expected: the `PORTS` column shows `8080/tcp` with **no** `0.0.0.0:->` host mapping
(internal only, as designed).

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Check off Phase 2 in the roadmap**

Change:
```
- [ ] Phase 2 — Private web search (self-hosted SearXNG)
```
to:
```
- [x] Phase 2 — Private web search (self-hosted SearXNG)
```

- [ ] **Step 2: Add a "Using web search" subsection**

After the `## Tuning` section, add:

```markdown
## Web search (Phase 2)

A self-hosted **SearXNG** container provides private web search. It runs on the compose
network with no published host port — only Open WebUI talks to it, and your prompts/chat
history never leave the Mac. Only the search query itself is forwarded to upstream engines,
and search is opt-in per message.

To use it: in a chat, toggle **Web Search** on in the message bar, then ask your question.
Answers come back with cited sources.

Config lives in [`searxng/settings.yml`](searxng/settings.yml) (JSON API enabled, rate
limiter off). Open WebUI is pointed at it via `SEARXNG_QUERY_URL` in
[`docker-compose.yml`](docker-compose.yml).
```

- [ ] **Step 3: Add a troubleshooting entry**

At the end of the `## Troubleshooting` section, add:

```markdown
- **Web search returns nothing / errors:** check `docker compose logs searxng`. A 403 or
  HTML response to the JSON API means SearXNG's `formats` list is missing `json` — confirm
  `searxng/settings.yml` lists `json` under `search.formats`, then `docker compose up -d`.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document Phase 2 web search, check off roadmap"
```

---

## Self-Review

**Spec coverage:**
- SearXNG service, internal-only, no Redis → Task 2 (service def, no ports) + Task 1 (`limiter: false`). ✓
- `settings.yml` with secret_key + json format → Task 1. ✓
- Open WebUI env vars (`ENABLE_WEB_SEARCH`, `WEB_SEARCH_ENGINE`, `SEARXNG_QUERY_URL`) → Task 2 Step 1. ✓
- Data-flow / connectivity verification → Task 3 (in-container JSON curl) + Task 4 (UI). ✓
- Error/edge cases (no secret_key, 403/no-json, network) → covered by Task 1 Step 2, Task 3 Step 3–4 checks. ✓
- Docs (README roadmap + usage + troubleshooting, compose header) → Task 5 + Task 2 Step 3. ✓

**Placeholder scan:** No TBD/TODO; every step has concrete commands or exact edits. The literal string `<query>` in `SEARXNG_QUERY_URL` is intentional — SearXNG/Open WebUI use it as the substitution token, not a placeholder to fill.

**Consistency:** Service name `searxng`, internal URL `http://searxng:8080`, and config path `searxng/settings.yml` are used identically across all tasks. ✓
