#!/bin/sh
set -eu

# SSE mode uses a PID lock file under data_dir. In Docker the main process is always
# PID 1, so a leftover lock from a crashed/restarted container looks "alive" and
# startup exits with code 75 in a restart loop.
LOCK="/app/data/knowledge-rag.lock"
if [ -f "$LOCK" ]; then
  echo "[knowledge-rag] removing stale lock from previous container run: $LOCK"
  rm -f "$LOCK"
fi

exec "$@"
