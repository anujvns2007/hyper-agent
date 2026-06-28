#!/usr/bin/env bash
# Pull public docs + Chroma index from the GPU host — no sync-docs.sh on Mac.
#
# Copies remote-gpu/knowledge-rag-docs/{documents,data} to local/knowledge-rag-docs/
# so a Mac with limited internet can run knowledge-rag-docs in Docker offline.
#
# Prereqs on GPU host: docs fetched and indexed (see remote-gpu/scripts/refresh-knowledge-rag-docs.sh).
#
# Usage:
#   GPU_HOST=user@gpu-host \
#   REMOTE_DOCS_RAG_DIR=~/work/repo/hyper-agent/remote-gpu/knowledge-rag-docs \
#   bash local/scripts/pull-knowledge-rag-docs.sh
#
#   bash local/scripts/pull-knowledge-rag-docs.sh --stop-remote   # pause GPU container during copy
#   bash local/scripts/pull-knowledge-rag-docs.sh --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$LOCAL_DIR/knowledge-rag-docs"
ENV_FILE="$LOCAL_DIR/.env"

STOP_REMOTE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --stop-remote) STOP_REMOTE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

GPU_HOST="${GPU_HOST:?Set GPU_HOST (e.g. user@gpu-host) in env or local/.env}"
REMOTE_DOCS_RAG_DIR="${REMOTE_DOCS_RAG_DIR:-~/work/repo/hyper-agent/remote-gpu/knowledge-rag-docs}"

SSH_OPTS=(-o RemoteCommand=none -o RequestTTY=no)
RSYNC=(rsync -avh --progress -e "ssh ${SSH_OPTS[*]}")
if [[ "$DRY_RUN" == 1 ]]; then
  RSYNC+=(--dry-run)
fi

# Runtime junk — recreated locally; do not copy from GPU or Mac.
RSYNC_EXCLUDES=(
  --exclude=__MACOSX
  --exclude='**/._*'
  --exclude=knowledge-rag.lock
  --exclude=backups
  --exclude=one-off-index.log
)

log() { printf '==> %s\n' "$*"; }

stop_local() {
  if docker info >/dev/null 2>&1; then
    (cd "$LOCAL_DIR" && docker compose stop knowledge-rag-docs 2>/dev/null) || true
  fi
}

start_local() {
  if [[ "$DRY_RUN" == 1 ]]; then
    return 0
  fi
  if docker info >/dev/null 2>&1; then
    log "Restarting local knowledge-rag-docs (Docker)..."
    bash "$SCRIPT_DIR/setup-knowledge-rag-docs.sh" --no-build
  fi
}

remote_exec() {
  ssh "${SSH_OPTS[@]}" "$GPU_HOST" "$@"
}

stop_remote() {
  log "Stopping knowledge-rag-docs on $GPU_HOST for a consistent index copy..."
  remote_exec "cd \"${REMOTE_DOCS_RAG_DIR%/knowledge-rag-docs}\" && docker compose stop knowledge-rag-docs" \
    || remote_exec "docker stop knowledge-rag-docs 2>/dev/null" \
    || true
}

start_remote() {
  if [[ "$STOP_REMOTE" == 1 && "$DRY_RUN" == 0 ]]; then
    log "Starting knowledge-rag-docs on $GPU_HOST..."
    remote_exec "cd \"${REMOTE_DOCS_RAG_DIR%/knowledge-rag-docs}\" && docker compose start knowledge-rag-docs" \
      || remote_exec "docker start knowledge-rag-docs 2>/dev/null" \
      || true
  fi
}

main() {
  if ! command -v rsync >/dev/null 2>&1; then
    echo "rsync is required." >&2
    exit 1
  fi

  mkdir -p "$DOCS_DIR/documents" "$DOCS_DIR/data"

  log "Source: $GPU_HOST:$REMOTE_DOCS_RAG_DIR/"
  log "Target: $DOCS_DIR/"

  stop_local

  if [[ "$STOP_REMOTE" == 1 ]]; then
    stop_remote
  else
    log "Tip: use --stop-remote if Chroma copy fails or index looks stale (copies while container is running)."
  fi

  trap 'start_remote' EXIT

  log "Pulling documents/ (public llms.txt, manuals, …)..."
  "${RSYNC[@]}" "${RSYNC_EXCLUDES[@]}" \
    "$GPU_HOST:${REMOTE_DOCS_RAG_DIR}/documents/" \
    "$DOCS_DIR/documents/"

  log "Pulling data/ (Chroma index + models_cache)..."
  "${RSYNC[@]}" "${RSYNC_EXCLUDES[@]}" \
    "$GPU_HOST:${REMOTE_DOCS_RAG_DIR}/data/" \
    "$DOCS_DIR/data/"

  rm -f "$DOCS_DIR/data/knowledge-rag.lock"

  if [[ "$DRY_RUN" == 1 ]]; then
    log "Dry run complete — no files changed."
    exit 0
  fi

  start_local

  doc_count="$(find "$DOCS_DIR/documents" -type f 2>/dev/null | wc -l | tr -d ' ')"
  chroma_ok=0
  [[ -d "$DOCS_DIR/data/chroma_db" ]] && chroma_ok=1

  cat <<EOF

Done.
  documents: $doc_count files under $DOCS_DIR/documents/
  chroma_db: $([ "$chroma_ok" == 1 ] && echo present || echo MISSING — reindex on GPU and pull again)

Start on Mac (no sync-docs.sh needed):
  bash local/scripts/setup-knowledge-rag-docs.sh

MCP: http://127.0.0.1:8179/mcp

Re-pull after GPU manifest or model changes:
  # on GPU: bash remote-gpu/scripts/refresh-knowledge-rag-docs.sh [--reindex]
  # on Mac:  bash local/scripts/pull-knowledge-rag-docs.sh --stop-remote
EOF
}

main "$@"
