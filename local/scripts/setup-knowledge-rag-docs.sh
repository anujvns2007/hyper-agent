#!/usr/bin/env bash
# Create venv and install knowledge-rag for native Mac (Apple Silicon).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$LOCAL_DIR/knowledge-rag-docs"
VENV="$DOCS_DIR/.venv"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

mkdir -p "$DOCS_DIR/documents" "$DOCS_DIR/data"

if [[ ! -d "$VENV" ]]; then
  echo "[setup-knowledge-rag-docs] creating venv at $VENV"
  uv venv "$VENV" --python 3.11
fi

# shellcheck source=/dev/null
source "$VENV/bin/activate"
uv pip install -r "$DOCS_DIR/requirements.txt"

echo ""
echo "Installed: $(knowledge-rag --version 2>/dev/null || python -c 'import importlib.metadata; print(importlib.metadata.version("knowledge-rag"))')"
echo ""
echo "Next steps:"
echo "  1. Fetch docs:  bash local/scripts/sync-docs.sh"
echo "  2. Start RAG:   bash local/scripts/run-knowledge-rag-docs.sh"
echo "  3. MCP URL:     http://127.0.0.1:8179/mcp"
