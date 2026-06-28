#!/usr/bin/env bash
# Build and start knowledge-rag-docs in Docker (CPU ONNX, host-mounted volumes).
#
# Mounts (override in local/.env):
#   KNOWLEDGE_RAG_CONFIG      → /app/config.yaml
#   KNOWLEDGE_RAG_DOCUMENTS   → /app/documents
#   KNOWLEDGE_RAG_DATA        → /app/data  (Chroma, models_cache, logs)
#
# Usage:
#   bash local/scripts/setup-knowledge-rag-docs.sh
#   bash local/scripts/setup-knowledge-rag-docs.sh --no-build
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$LOCAL_DIR/knowledge-rag-docs"

BUILD=1
if [[ "${1:-}" == "--no-build" ]]; then
  BUILD=0
elif [[ -n "${1:-}" ]]; then
  echo "Usage: setup-knowledge-rag-docs.sh [--no-build]" >&2
  exit 1
fi

log() { printf '==> %s\n' "$*"; }

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Start Docker Desktop and retry." >&2
  exit 1
fi

if [[ ! -f "$LOCAL_DIR/.env" ]]; then
  echo "Missing $LOCAL_DIR/.env — run: cp local/.env.example local/.env" >&2
  exit 1
fi

mkdir -p "$DOCS_DIR/documents" "$DOCS_DIR/data"
rm -f "$DOCS_DIR/data/knowledge-rag.lock"

if [[ ! -f "$DOCS_DIR/config.yaml" ]]; then
  echo "Missing $DOCS_DIR/config.yaml" >&2
  exit 1
fi

cd "$LOCAL_DIR"
if [[ "$BUILD" == 1 ]]; then
  log "Building knowledge-rag-docs image..."
  docker compose build knowledge-rag-docs
fi

log "Starting knowledge-rag-docs container..."
docker compose up -d knowledge-rag-docs

log "Waiting for MCP on http://127.0.0.1:8179/mcp ..."
ready=0
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8179/mcp 2>/dev/null || echo 000)"
  if [[ "$code" == "406" || "$code" == "200" ]]; then
    ready=1
    break
  fi
  sleep 5
done

if [[ "$ready" != 1 ]]; then
  echo "Timed out waiting for knowledge-rag-docs." >&2
  docker compose ps knowledge-rag-docs
  docker logs knowledge-rag-docs 2>&1 | tail -30
  exit 1
fi

cat <<EOF

knowledge-rag-docs is up.
  MCP:   http://127.0.0.1:8179/mcp
  logs:  docker logs -f knowledge-rag-docs
  stop:  docker compose -f local/docker-compose.yaml stop knowledge-rag-docs

Populate docs/index if empty:
  bash local/scripts/sync-docs.sh
  bash local/scripts/pull-knowledge-rag-docs.sh --stop-remote

Register Claude MCP (once):
  bash local/scripts/setup-claude-mcp.sh
EOF
