#!/usr/bin/env bash
# Run a full force-index in a one-off container (no MCP server). Use when startup
# indexing is interrupted — logs go to knowledge-rag-docs/data/one-off-index.log
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="$ROOT/knowledge-rag-docs/data/one-off-index.log"
mkdir -p "$(dirname "$LOG")"

echo "[one-off-index] $(date -Is) starting..." | tee -a "$LOG"

docker compose stop knowledge-rag-docs 2>/dev/null || true

docker compose run --rm --no-deps --entrypoint sh knowledge-rag-docs -c \
  'rm -rf /app/data/chroma_db /app/data/index_metadata.json /app/data/knowledge-rag.lock /app/data/backups/*'

docker compose run --rm --no-deps --entrypoint python3 knowledge-rag-docs -c "
from mcp_server.server import KnowledgeOrchestrator
print('Starting clean force index...')
ko = KnowledgeOrchestrator()
stats = ko.index_all(force=True)
print('DONE', stats)
" 2>&1 | tee -a "$LOG"

docker compose up -d knowledge-rag-docs
echo "[one-off-index] $(date -Is) finished — see $LOG" | tee -a "$LOG"
