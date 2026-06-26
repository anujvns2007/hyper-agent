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

# config.yaml is mounted read-only; copy to a writable runtime file (GPU patch below).
RUNTIME_DIR=/tmp/knowledge-rag-runtime
mkdir -p "$RUNTIME_DIR"
cp /app/config.yaml "$RUNTIME_DIR/config.yaml"

if [ "${KNOWLEDGE_RAG_GPU:-0}" = "1" ]; then
  echo "[knowledge-rag] KNOWLEDGE_RAG_GPU=1 — enabling CUDA embeddings in runtime config"
  sed -i 's/^[[:space:]]*gpu:[[:space:]]*false/    gpu: true/' "$RUNTIME_DIR/config.yaml"
fi

cd "$RUNTIME_DIR"
exec "$@"
