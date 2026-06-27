#!/bin/sh
set -eu

PROXY_PORT="${HEADROOM_PORT:-8787}"
MCP_PORT="${HEADROOM_MCP_PORT:-8790}"
PROXY_URL="http://127.0.0.1:${PROXY_PORT}"

python3 -m headroom.cli proxy "$@" &
PROXY_PID=$!

cleanup() {
  kill "$PROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 60); do
  if python3 -c "import urllib.request; urllib.request.urlopen('${PROXY_URL}/livez', timeout=1)" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

echo "[headroom] proxy ready on ${PROXY_URL}; MCP streamable HTTP on :${MCP_PORT}/mcp"

exec supergateway \
  --stdio "python3 -m headroom.cli mcp serve --proxy-url ${PROXY_URL}" \
  --port "$MCP_PORT" \
  --outputTransport streamableHttp \
  --streamableHttpPath /mcp \
  --baseUrl "http://127.0.0.1:${MCP_PORT}"
