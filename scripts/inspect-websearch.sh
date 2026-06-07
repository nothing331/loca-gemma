#!/usr/bin/env bash
# Inspect exactly what Open WebUI's web search FETCHED and STORED for the most
# recent query — the raw text the model actually received, vs. what you see on
# the live website. Use it to diagnose thin/"No sources found" web answers
# (JS-rendered pages, bot-blocked sources, nav boilerplate, etc.).
#
# Usage:
#   ./scripts/inspect-websearch.sh                  # latest query: dump stored content
#   ./scripts/inspect-websearch.sh spurs knicks 0-2 # also report if those terms were captured
#
# Requires the open-webui container to be running.
set -euo pipefail
cd "$(dirname "$0")/.."

TERMS="${*:-}"

# Most recent ephemeral web-search-* collection, taken from the container logs.
COL=$(docker compose logs open-webui --no-log-prefix 2>/dev/null \
  | grep -a "added .* items to collection web-search-" \
  | tail -1 | sed -E 's/.*collection (web-search-[a-f0-9]+).*/\1/')

if [ -z "${COL:-}" ]; then
  echo "No web-search collection found in logs — run a web search in the UI first."
  exit 1
fi

# WEBUI_SECRET_KEY lives in the running process env; read it from PID 1 so the
# helper can bootstrap Open WebUI's config. Python reads from stdin (cwd is on
# sys.path) so open_webui is importable. App-bootstrap noise goes to stderr.
docker exec -i -e COL="$COL" -e TERMS="$TERMS" open-webui sh -c \
  'cd /app/backend && export WEBUI_SECRET_KEY=$(tr "\0" "\n" </proc/1/environ | sed -n "s/^WEBUI_SECRET_KEY=//p") && python3 -' \
  < scripts/_inspect_ws.py 2>/dev/null
