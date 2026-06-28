# Local Stack (MacBook)

Docker Compose for **Headroom** and **code-graph**; native tools for Serena and **knowledge-rag-docs**.

## Serena (native uvx)

Install once:

```bash
# uvx must be on PATH (~/.local/bin)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Claude Code** — run `local/scripts/setup-claude-mcp.sh` to write Headroom/model env to `~/.claude/settings.json` and register Headroom MCP at `http://127.0.0.1:8790/mcp`. Serena hooks live in `.claude/settings.json`.

**Codex** — add `local/codex.serena.example.toml` to `~/.codex/config.toml`. Point Headroom at `http://127.0.0.1:8787` in your Codex provider config.

## Services

| Service | How | Port | Purpose |
|---------|-----|------|---------|
| **headroom-proxy** | Docker | 8787 / 8790 | LLM proxy + Headroom MCP |
| **code-graph-mcp** | Docker | 5070 | Call-graph MCP |
| **knowledge-rag-docs** | **Native** | 8179 | Public docs RAG (ONNX on Apple Silicon) |

## Quick start

```bash
cd local
cp .env.example .env   # set PROJECT_ROOT; optional VLLM_UPSTREAM_URL

# Docker stack (Headroom + code-graph)
docker compose up -d --build

# Native docs RAG (one-time setup, then run)
bash scripts/setup-knowledge-rag-docs.sh
bash scripts/pull-knowledge-rag-docs.sh --stop-remote   # from GPU; no sync-docs on Mac
bash scripts/run-knowledge-rag-docs.sh --background
```

Or fetch docs on the Mac if you have bandwidth:

```bash
bash scripts/sync-docs.sh
bash scripts/run-knowledge-rag-docs.sh --background
```

First run without a GPU pull: `sync-docs.sh` downloads public docs, then `knowledge-rag` indexes them on native ARM CPU (`bge-large-en-v1.5`, 1024D). First index can take a while — unload heavy Ollama models during reindex if memory is tight.

Headroom forwards to vLLM on the GPU host. Start the SSH tunnel if using `host.docker.internal:8000`:

```bash
ssh -N -L 8000:127.0.0.1:8000 user@gpu-host
```

Or set `VLLM_UPSTREAM_URL` to a Tailscale/LAN address in `.env`.

### Headroom memory & learning

Headroom runs with `--memory --learn`: Claude, Codex, and any client using the same proxy share a persistent memory store (facts injected into context + `memory_save` / `memory_search` tools). Live traffic learning extracts repeated patterns and persists them after enough observations (default `min-evidence: 5`). Data is stored in `local/headroom/data/` (not in your repo — `/workspace` is read-only). Project scope follows `PROJECT_ROOT` via `--memory-project-root /workspace`.

Memory embeddings use `Qdrant/all-MiniLM-L6-v2-onnx` from the host HuggingFace cache (`HF_CACHE`, default `~/.cache/huggingface`), mounted read-only into the container.

## Claude Code

```bash
ssh -N -L 8000:127.0.0.1:8000 user@gpu-host   # vLLM only
cd local && docker compose up -d --build
bash scripts/setup-knowledge-rag-docs.sh      # once
bash scripts/run-knowledge-rag-docs.sh --background
bash scripts/setup-claude-mcp.sh              # writes ~/.claude/settings.json
claude    # from repo root
```

## knowledge-rag-docs (native)

| Path | Purpose |
|------|---------|
| `knowledge-rag-docs/config.yaml` | Embedding model, chunking, categories |
| `knowledge-rag-docs/documents/` | Fetched public docs |
| `knowledge-rag-docs/data/` | Chroma index + logs |
| `knowledge-rag-docs/.venv/` | Python venv (created by setup script) |

**Scripts**

| Script | Purpose |
|--------|---------|
| `scripts/setup-knowledge-rag-docs.sh` | Create venv, `pip install knowledge-rag[server]` |
| `scripts/pull-knowledge-rag-docs.sh` | **Pull `documents/` + `data/` from GPU** (no Mac internet) |
| `scripts/sync-docs.sh` | Fetch docs from manifest on Mac (needs internet) |
| `scripts/run-knowledge-rag-docs.sh` | Foreground server |
| `scripts/run-knowledge-rag-docs.sh --background` | Daemon on `:8179` |

MCP URL: `http://127.0.0.1:8179/mcp`

**Reindex after model change**

```bash
kill "$(cat knowledge-rag-docs/data/knowledge-rag-docs.pid)" 2>/dev/null || true
rm -rf knowledge-rag-docs/data/chroma_db knowledge-rag-docs/data/index_metadata.json
bash scripts/run-knowledge-rag-docs.sh --background
```

**Index on GPU host, use on Mac (limited bandwidth)** — on the GPU machine:

```bash
bash remote-gpu/scripts/refresh-knowledge-rag-docs.sh --reindex
```

On Mac (set `GPU_HOST` and optional `REMOTE_DOCS_RAG_DIR` in `local/.env`):

```bash
bash local/scripts/pull-knowledge-rag-docs.sh --stop-remote
bash local/scripts/run-knowledge-rag-docs.sh --background
```

Pulls `documents/`, `chroma_db/`, `index_metadata.json`, and `models_cache/` — no `sync-docs.sh` on Mac. Embedding model + dimensions must match (`BAAI/bge-large-en-v1.5`, 1024D).

## Codex

Add Serena via `local/codex.serena.example.toml`. Configure Headroom provider with `base_url = "http://127.0.0.1:8787"`. Register `knowledge-rag-docs` at `http://127.0.0.1:8179/mcp`.

## Troubleshooting

**Headroom unhealthy** — Check `docker logs headroom-ai`. Ensure vLLM tunnel is up (`curl -s http://127.0.0.1:8000/v1/models` from Mac host).

**Headroom cannot reach vLLM** — Default upstream is `http://host.docker.internal:8000`. Verify tunnel or set `VLLM_UPSTREAM_URL` to the GPU's reachable IP.

**knowledge-rag-docs not listening** — Check `knowledge-rag-docs/data/knowledge-rag-docs.log`. Ensure setup ran and docs exist: `ls knowledge-rag-docs/documents/`. Test: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8179/mcp`.

**Slow first index** — Normal on CPU with ~50 llms.txt sources. Stop Ollama during reindex, or build index on `remote-gpu` and rsync `data/`.
