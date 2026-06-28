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

echo "[refresh] recreating docs-sync (reload manifest bind mount)..."
docker compose up -d --force-recreate docs-sync

echo "[refresh] fetching docs from fetch-docs-manifest.tsv..."
# docs-sync installs curl on first start; wait after recreate
for _ in $(seq 1 30); do
  if docker compose exec -T docs-sync sh -c 'command -v curl >/dev/null' 2>/dev/null; then
    break
  fi
  sleep 2
done
docker compose exec -T docs-sync /fetch-docs.sh

if [[ "$REINDEX" == 1 ]]; then
  echo "[refresh] wiping index and running one-off force index (see data/one-off-index.log)..."
  bash scripts/run-one-off-index.sh
else
  echo "[refresh] restarting knowledge-rag-docs (file watcher re-indexes changes)..."
  docker compose restart knowledge-rag-docs
fi

echo "[refresh] done — MCP http://127.0.0.1:8179/mcp (tunnel :8179 from Mac if used)"
