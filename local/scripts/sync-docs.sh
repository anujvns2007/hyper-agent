#!/usr/bin/env bash
# Download public docs into local/knowledge-rag-docs/documents/ (mounted into Docker).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LOCAL_DIR/.." && pwd)"

export DOCS_ROOT="$LOCAL_DIR/knowledge-rag-docs/documents"
export MANIFEST="$REPO_ROOT/remote-gpu/knowledge-rag-docs/fetch-docs-manifest.tsv"

mkdir -p "$DOCS_ROOT"
bash "$REPO_ROOT/remote-gpu/knowledge-rag-docs/fetch-docs.sh"

echo ""
echo "Docs updated. knowledge-rag file watcher will re-index (Docker) or restart:"
echo "  bash local/scripts/setup-knowledge-rag-docs.sh --no-build"
