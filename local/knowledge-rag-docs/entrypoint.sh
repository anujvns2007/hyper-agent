#!/bin/sh
set -eu

LOCK="/app/data/knowledge-rag.lock"
if [ -f "$LOCK" ]; then
  echo "[knowledge-rag] removing stale lock from previous container run: $LOCK"
  rm -f "$LOCK"
fi

exec "$@"
