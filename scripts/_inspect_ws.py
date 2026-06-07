"""Dump the raw text Open WebUI's web search stored for one ephemeral
web-search-* vector collection. Run inside the open-webui container via
scripts/inspect-websearch.sh (expects COL and optional TERMS env vars)."""
import os
import collections
from open_webui.retrieval.vector.factory import VECTOR_DB_CLIENT

col = os.environ["COL"]
terms = [t for t in os.environ.get("TERMS", "").split() if t]

res = VECTOR_DB_CLIENT.get(collection_name=col)
docs = res.documents[0]
metas = res.metadatas[0]

print(f"collection : {col}")
print(f"total chunks: {len(docs)}")

if terms:
    blob = " ".join(docs).lower()
    print("\nkeyword presence (across ALL fetched chunks, not just the top-K the model saw):")
    for t in terms:
        print(f"  {t!r:20} {'FOUND' if t.lower() in blob else 'missing'}")

print("\nper-source — chunk count + first ~400 chars actually stored:")
by_src = collections.defaultdict(list)
for d, m in zip(docs, metas):
    by_src[(m.get("source") or m.get("name") or "?")].append(d)
for url, chunks in by_src.items():
    print(f"\n--- {url}  ({len(chunks)} chunks) ---")
    print("   ", " ".join(chunks)[:400].replace("\n", " "))
