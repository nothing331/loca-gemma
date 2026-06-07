# loca-gemma

A private, local AI assistant running entirely on your own machine — no data leaves the Mac. Built on **Ollama** (model inference) + **Open WebUI** (chat interface), using a tuned **Gemma 4** model.

## What this gives you

- 💬 A ChatGPT-style web interface, fully local
- 🖼️ Image understanding (Gemma 4 e4b is multimodal — captioning, OCR, visual Q&A)
- 📄 Document/spreadsheet handling via built-in RAG and code execution (later phase)
- 🔍 Private web search via SearXNG (later phase)

## Stack

```
Ollama (native on macOS)  ←→  Open WebUI (Docker, port 3000)
  └─ gemma4-tuned (e4b, num_ctx 8192)
```

Ollama runs natively on the Mac for best Metal/GPU performance; Open WebUI runs in Docker and connects to it at `host.docker.internal:11434`.

## Prerequisites (already set up on this machine)

- [Ollama](https://ollama.com) running (`http://localhost:11434` returns "Ollama is running")
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) running
- The tuned model built: `ollama create gemma4-tuned -f Modelfile.gemma4-tuned`

## Quick start

1. **Make sure Ollama and Docker Desktop are running.**

2. **Start the chat interface:**
   ```bash
   docker compose up -d
   ```

3. **Open** http://localhost:3000 and create your account (first account = admin).

4. **Select the model:** in the model dropdown, choose **`gemma4-tuned`**.

5. **Try it:**
   - Type a message.
   - Click the 📎 attachment icon to upload an image and ask about it.

## Tuning

The `gemma4-tuned` model is defined in [`Modelfile.gemma4-tuned`](Modelfile.gemma4-tuned):
- `num_ctx 8192` — Ollama defaults to 4096 on this hardware; 8192 is comfortable on 16 GB.
  Verified footprint at 8K is ~3.3 GB on GPU, so you can likely raise this to 16384 or 32768.
  After editing, rebuild: `ollama create gemma4-tuned -f Modelfile.gemma4-tuned`, then
  check `ollama ps` still shows **100% GPU**.
- Sampling uses Google's recommended defaults (temp 1 / top_p 0.95 / top_k 64).
  For deterministic tasks (spreadsheet code, structured output), lower temperature to ~0.3.

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

## Common commands

```bash
docker compose up -d            # start Open WebUI
docker compose logs -f          # watch logs
docker compose down             # stop (chat history persists in the volume)
ollama ps                       # see loaded model + GPU residency + context
ollama list                     # list installed models
```

## Roadmap

- [x] Phase 1 — Ollama + Open WebUI chat with tuned Gemma 4, image input
- [x] Phase 2 — Private web search (self-hosted SearXNG)
- [ ] Phase 3 — Sensitive spreadsheet analysis (code interpreter / local pandas)
- [ ] Phase 4 — Document RAG (nomic-embed-text is already installed for embeddings)

## Troubleshooting

- **Open WebUI can't see any models:** confirm Ollama is running on the host
  (`curl http://localhost:11434`), and that the connection URL in Open WebUI
  Settings → Connections is `http://host.docker.internal:11434` (not `localhost`).
- **Model is slow / spills to CPU:** run `ollama ps`; if PROCESSOR isn't "100% GPU",
  lower `num_ctx` in the Modelfile and rebuild.
- **Web search returns nothing / errors:** check `docker compose logs searxng`. A 403 or
  HTML response to the JSON API means SearXNG's `formats` list is missing `json` — confirm
  `searxng/settings.yml` lists `json` under `search.formats`, then `docker compose up -d`.
