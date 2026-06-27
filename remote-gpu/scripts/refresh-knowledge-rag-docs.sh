#!/usr/bin/env bash
# On the GPU host: fetch latest docs from manifest and restart knowledge-rag-docs.
# Run after git pull when fetch-docs-manifest.tsv or config.yaml changed.
#
#   bash scripts/refresh-knowledge-rag-docs.sh
#   bash scripts/refresh-knowledge-rag-docs.sh --reindex   # wipe Chroma and rebuild
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REINDEX=0
if [[ "${1:-}" == "--reindex" ]]; then
  REINDEX=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--reindex]" >&2
  exit 1
fi

if ! docker compose ps --status running knowledge-rag-docs docs-sync 2>/dev/null | grep -q knowledge-rag; then
  echo "Starting docs-sync and knowledge-rag-docs..."
  docker compose up -d docs-sync knowledge-rag-docs
fi

echo "[refresh] fetching docs from fetch-docs-manifest.tsv..."
docker compose exec -T docs-sync /fetch-docs.sh

if [[ "$REINDEX" == 1 ]]; then
  echo "[refresh] wiping index (embedding model/dim must match config.yaml)..."
  docker compose stop knowledge-rag-docs
  rm -rf knowledge-rag-docs/data/chroma_db knowledge-rag-docs/data/index_metadata.json
  docker compose up -d knowledge-rag-docs
else
  echo "[refresh] restarting knowledge-rag-docs (file watcher re-indexes changes)..."
  docker compose restart knowledge-rag-docs
fi

echo "[refresh] done — MCP http://127.0.0.1:8179/mcp (tunnel :8179 from Mac if used)"
