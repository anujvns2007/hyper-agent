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

# SSE on :5071 (optional). Streamable HTTP on :5070 for Claude Code / Codex.
supergateway \
  --stdio "codebase-memory-mcp" \
  --port 5071 \
  --outputTransport sse \
  --baseUrl "http://127.0.0.1:5071" \
  --ssePath /sse \
  --messagePath /message &

exec supergateway \
  --stdio "codebase-memory-mcp" \
  --port 5070 \
  --outputTransport streamableHttp \
  --streamableHttpPath /mcp \
  --baseUrl "http://127.0.0.1:5070"
