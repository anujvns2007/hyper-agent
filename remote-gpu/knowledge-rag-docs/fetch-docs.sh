#!/bin/sh
# Download public llms.txt docs into documents/ (see DOCS_ROOT).
# Add rows to docs-manifest.tsv: category<TAB>url<TAB>filename
set -eu

DOCS_ROOT="${DOCS_ROOT:-/documents}"
MANIFEST="${MANIFEST:-/fetch-docs-manifest.tsv}"
mkdir -p "${DOCS_ROOT}"

log() { printf '[fetch-docs] %s\n' "$*"; }

fetch() {
  category="$1"
  url="$2"
  outfile="$3"
  mkdir -p "${DOCS_ROOT}/${category}"
  dest="${DOCS_ROOT}/${category}/${outfile}"
  log "GET ${url} -> ${dest}"
  if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 \
      -o "${dest}.tmp" "${url}"; then
    mv "${dest}.tmp" "${dest}"
    log "  ok ($(wc -c < "${dest}") bytes)"
  else
    rm -f "${dest}.tmp"
    log "  skipped (fetch failed)"
  fi
}

if [ -f "${MANIFEST}" ]; then
  while read -r line; do
    case "${line}" in ''|\#*) continue ;; esac
    category=$(printf '%s' "${line}" | cut -f1)
    url=$(printf '%s' "${line}" | cut -f2)
    outfile=$(printf '%s' "${line}" | cut -f3)
    fetch "${category}" "${url}" "${outfile}"
  done < "${MANIFEST}"
else
  log "manifest not found: ${MANIFEST}"
  exit 1
fi

log "done — knowledge-rag file watcher will re-index changed files"
