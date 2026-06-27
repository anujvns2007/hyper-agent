#!/usr/bin/env bash
# Run knowledge-rag MCP server natively on Mac (127.0.0.1:8179).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$LOCAL_DIR/knowledge-rag-docs"
VENV="$DOCS_DIR/.venv"
PID_FILE="$DOCS_DIR/data/knowledge-rag-docs.pid"
LOG_FILE="$DOCS_DIR/data/knowledge-rag-docs.log"

usage() {
  cat <<'EOF'
Usage: run-knowledge-rag-docs.sh [--background]

  (default)  Foreground — logs to stderr; Ctrl-C to stop.
  --background  Daemonize; PID and logs under knowledge-rag-docs/data/
EOF
}

BACKGROUND=0
if [[ "${1:-}" == "--background" ]]; then
  BACKGROUND=1
elif [[ -n "${1:-}" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$VENV" ]]; then
  echo "venv not found. Run: bash local/scripts/setup-knowledge-rag-docs.sh" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$VENV/bin/activate"

cd "$DOCS_DIR"
mkdir -p documents data

LOCK="data/knowledge-rag.lock"
if [[ -f "$LOCK" ]]; then
  echo "[knowledge-rag-docs] removing stale lock: $LOCK"
  rm -f "$LOCK"
fi

if [[ "$BACKGROUND" == 1 ]]; then
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Already running (pid $(cat "$PID_FILE")). Stop with: kill \$(cat $PID_FILE)" >&2
    exit 1
  fi
  nohup knowledge-rag --transport streamable-http >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  echo "Started knowledge-rag-docs (pid $(cat "$PID_FILE"))"
  echo "  MCP:  http://127.0.0.1:8179/mcp"
  echo "  log:  $LOG_FILE"
else
  echo "[knowledge-rag-docs] MCP http://127.0.0.1:8179/mcp (config.yaml in $DOCS_DIR)"
  exec knowledge-rag --transport streamable-http
fi
