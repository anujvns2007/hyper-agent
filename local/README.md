# Local Stack (MacBook)

Docker Compose for **Headroom**, **code-graph**, and **knowledge-rag-docs**; native tools for Serena.

## Serena (native uvx)

Install once:

```bash
# uvx must be on PATH (~/.local/bin)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Claude Code** — run `local/scripts/setup-claude-mcp.sh` to write Headroom/model env to `~/.claude/settings.json` and register Headroom MCP at `http://127.0.0.1:8790/mcp`. Serena hooks live in `.claude/settings.json`.

**Codex** — point `model_providers.headroom.base_url` at `http://127.0.0.1:8787` in `~/.codex/config.toml`. Register MCP servers at the same URLs as Claude Code.

## Services

| Service | How | Port | Purpose |
|---------|-----|------|---------|
| **headroom-proxy** | Docker | 8787 / 8790 | LLM proxy + Headroom MCP |
| **code-graph-mcp** | Docker | 5070 | Call-graph MCP |
| **knowledge-rag-docs** | Docker | 8179 | Public docs RAG (CPU ONNX) |

## Quick start

```bash
cd local
cp .env.example .env   # set PROJECT_ROOT; optional VLLM_UPSTREAM_URL

# Full stack
docker compose up -d --build

# Docs RAG only
bash scripts/setup-knowledge-rag-docs.sh

# Populate docs/index (pick one):
bash scripts/pull-knowledge-rag-docs.sh --stop-remote   # from GPU
# bash scripts/sync-docs.sh                            # or fetch on Mac
```

Or fetch docs on the Mac if you have bandwidth:

```bash
bash scripts/sync-docs.sh
bash scripts/setup-knowledge-rag-docs.sh --no-build
```

First run without a GPU pull: `sync-docs.sh` downloads public docs, then `knowledge-rag` indexes them on CPU (`bge-large-en-v1.5`, 1024D). First index can take a while.

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
bash scripts/setup-claude-mcp.sh              # writes ~/.claude/settings.json
claude    # from repo root
```

## knowledge-rag-docs

CPU ONNX in Docker. **documents/**, **data/** (Chroma + `models_cache/`), and **config.yaml** are bind-mounted from the host — nothing heavy lives in the image.

| Path | Purpose |
|------|---------|
| `knowledge-rag-docs/config.yaml` | Embedding model, chunking, categories |
| `knowledge-rag-docs/documents/` | Fetched public docs |
| `knowledge-rag-docs/data/` | Chroma index, `models_cache/`, logs |

Override mount paths in `.env`:

```bash
KNOWLEDGE_RAG_DOCUMENTS=/path/to/documents
KNOWLEDGE_RAG_DATA=/path/to/data
KNOWLEDGE_RAG_CONFIG=/path/to/config.yaml
```

**Scripts**

| Script | Purpose |
|--------|---------|
| `scripts/setup-knowledge-rag-docs.sh` | Build/start Docker container |
| `scripts/pull-knowledge-rag-docs.sh` | Pull `documents/` + `data/` from GPU |
| `scripts/sync-docs.sh` | Fetch docs from manifest on Mac |

```bash
docker compose up -d --build knowledge-rag-docs
docker logs -f knowledge-rag-docs
```

MCP URL: `http://127.0.0.1:8179/mcp`

**Reindex after model change**

```bash
docker compose stop knowledge-rag-docs
rm -rf knowledge-rag-docs/data/chroma_db knowledge-rag-docs/data/index_metadata.json
docker compose up -d knowledge-rag-docs
```

**Index on GPU host, use on Mac (limited bandwidth)** — on the GPU machine:

```bash
bash remote-gpu/scripts/refresh-knowledge-rag-docs.sh --reindex
```

On Mac (set `GPU_HOST` and optional `REMOTE_DOCS_RAG_DIR` in `local/.env`):

```bash
bash local/scripts/pull-knowledge-rag-docs.sh --stop-remote
```

Pull restarts the Docker container automatically. Embedding model + dimensions must match (`BAAI/bge-large-en-v1.5`, 1024D).

## Codex

Add Serena via `uvx` (see `setup-claude-mcp.sh` output). Configure Headroom provider with `base_url = "http://127.0.0.1:8787"`. Register `knowledge-rag-docs` at `http://127.0.0.1:8179/mcp`.

## Troubleshooting

**Headroom unhealthy** — Check `docker logs headroom-ai`. Ensure vLLM tunnel is up (`curl -s http://127.0.0.1:8000/v1/models` from Mac host).

**Headroom cannot reach vLLM** — Default upstream is `http://host.docker.internal:8000`. Verify tunnel or set `VLLM_UPSTREAM_URL` to the GPU's reachable IP.

**knowledge-rag-docs not listening** — `docker logs knowledge-rag-docs`. Ensure docs exist: `ls knowledge-rag-docs/documents/`. Test: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8179/mcp` (406 = up).

**Slow first index** — Normal on CPU with ~50 llms.txt sources. Build index on `remote-gpu` and pull `data/`.
