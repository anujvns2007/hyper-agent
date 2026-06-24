#!/bin/sh
set -eu

cd /workspace

if [ -n "$(find /workspace -mindepth 1 -maxdepth 3 -type f 2>/dev/null | head -1)" ]; then
  echo "[code-graph] indexing /workspace (fast mode)..."
  if codebase-memory-mcp cli index_repository '{"repo_path":"/workspace","mode":"fast"}'; then
    echo "[code-graph] initial index complete"
  else
    echo "[code-graph] initial index failed — MCP tools may index on first query"
  fi
else
  echo "[code-graph] /workspace is empty — set PROJECT_ROOT in .env"
fi

exec supergateway \
  --stdio "codebase-memory-mcp" \
  --port 5070 \
  --baseUrl "http://127.0.0.1:5070" \
  --ssePath /sse \
  --messagePath /message
