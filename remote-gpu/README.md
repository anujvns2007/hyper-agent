# Remote GPU Stack

Docker Compose services that run on a **Linux GPU host**: local LLM inference (vLLM) and a searchable index of **public documentation**.

Headroom runs on your Mac — see [../local/README.md](../local/README.md). Your Mac connects to this stack via **SSH tunnel** — see [../README.md](../README.md).

## Services

| Service | Port | Purpose |
|---------|------|---------|
| **vllm-backend** | 8000 | OpenAI-compatible LLM (Qwen3.6-35B-A3B-FP8) |
| **knowledge-rag-docs** | 8179 | Semantic search over fetched public docs (MCP SSE) |
| **docs-sync** | — | Downloads docs from manifest on a schedule |

## Quick start

On the **GPU host**, from this directory:

```bash
cd remote-gpu
cp .env.example .env   # optional: adjust DOCS_SYNC_INTERVAL_SECONDS

hf download Qwen/Qwen3.6-35B-A3B-FP8

docker compose up -d --build
docker compose ps
docker logs -f vllm-qwen3.6    # wait for model load
```

First vLLM startup can take several minutes.

## MacBook tunnel

From your laptop (keep this session open while coding):

```bash
ssh -N \
  -L 8000:127.0.0.1:8000 \
  -L 8179:127.0.0.1:8179 \
  user@gpu-host
```

- **8000** — vLLM upstream for local Headroom (`host.docker.internal:8000`)
- **8179** — knowledge-rag-docs MCP

Optional `~/.ssh/config`:

```
Host gpu-agent
  HostName gpu-host.example.com
  User your-user
  LocalForward 8000 127.0.0.1:8000
  LocalForward 8179 127.0.0.1:8179
```

## Codex (MacBook) — `~/.codex/config.toml`

Codex **does not** reliably use `OPENAI_BASE_URL` for custom/local providers. Configure `model_providers` in TOML instead.

Point the Headroom provider at **local** Headroom (`http://127.0.0.1:8787`), not the GPU host.

```bash
# On Mac — start local Headroom + tunnel
cd local && docker compose up -d --build
ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host

export OPENAI_API_KEY=dummy
codex --profile hyper-agent
```

**Profile settings** (example):

| Key | Value | Why |
|-----|-------|-----|
| `model_provider` | `headroom` | Routes via local Headroom → tunneled vLLM |
| `model` | `qwen3.6` | Must match vLLM `--served-model-name` |
| `wire_api` | `responses` | Required for Codex tool loop |
| `approval_policy` | `never` | No approval prompts (trusted dev machine) |
| `sandbox_mode` | `danger-full-access` | Shell/file tools run without sandbox limits |

Use `127.0.0.1`, not `localhost` (avoids IPv6 `/v1/responses` streaming issues).

**Debug tool calling** — switch profile to direct vLLM (bypass Headroom):

```toml
model_provider = "vllm-direct"
# base_url = "http://127.0.0.1:8000/v1"
```

vLLM is started with `--enable-auto-tool-choice` and `--tool-call-parser qwen3_coder` so Codex gets structured tool calls instead of raw `<tool_call>` text.

## Claude Code (via local Headroom)

Headroom URL and model IDs live in `~/.claude/settings.json` (written by `local/scripts/setup-claude-mcp.sh`).

```bash
cd /path/to/agent && claude
```

Set `ENABLE_TOOL_SEARCH=false` until vLLM/Qwen supports deferred `tool_reference` blocks in tool results.

## Verify

```bash
# On GPU host
curl -s http://127.0.0.1:8000/v1/models

# On Mac (tunnel must be up)
curl -s http://127.0.0.1:8000/v1/models
curl -s http://127.0.0.1:8787/livez          # local Headroom
curl -s -o /dev/null -w "docs-rag: %{http_code}\n" --max-time 3 http://127.0.0.1:8179/mcp
```

## Layout

```
remote-gpu/
├── docker-compose.yaml
├── .env.example
├── scripts/
│   └── refresh-knowledge-rag-docs.sh   # fetch manifest + restart/reindex
└── knowledge-rag-docs/
    ├── config.yaml
    ├── fetch-docs-manifest.tsv   # shared with Mac — local/scripts/sync-docs.sh uses this file
    ├── fetch-docs.sh
    ├── documents/             # downloaded docs (gitignored)
    └── data/                  # vector index (gitignored)
```

## Documentation index (manifest categories)

`fetch-docs-manifest.tsv` is the **single source of truth** for both Mac (native) and GPU (Docker). Categories include:

| Category | Examples |
|----------|----------|
| **Languages** | python, typescript, javascript, go, rust, cpp, dart/flutter |
| **Web / app** | react, nextjs, fastapi |
| **Infra** | docker, kubernetes, helm |
| **Data** | postgres, redis, database (SQLite, SQLAlchemy) |
| **Messaging** | matrix, nats, rabbitmq |
| **Protocols** | http (RFC 911x), networking (TCP/UDP/QUIC), security-protocols, pqc |
| **Media** | gstreamer, ffmpeg, webrtc, livekit |
| **Dev tools** | git, jira, bitbucket |

Search hints for each category are in `knowledge-rag-docs/config.yaml` → `category_mappings`.

## Add documentation sources

Append a row to `knowledge-rag-docs/fetch-docs-manifest.tsv`:

```tsv
# category<TAB>url<TAB>filename
mylib	https://example.com/llms.txt	llms.txt
```

Then restart sync or wait for the next scheduled fetch:

```bash
docker compose exec docs-sync /fetch-docs.sh
```

Categories map to search hints in `knowledge-rag-docs/config.yaml` → `category_mappings`.

After editing the manifest or `config.yaml`, refresh on the GPU host:

```bash
bash scripts/refresh-knowledge-rag-docs.sh
```

Use `--reindex` when chunking, embedding model, or dimensions change (wipes Chroma and rebuilds):

```bash
bash scripts/refresh-knowledge-rag-docs.sh --reindex
```

On Mac, run `bash local/scripts/sync-docs.sh` and restart native knowledge-rag-docs (same manifest file).

## Customization

**Change LLM model** — edit `vllm-backend.command` in `docker-compose.yaml`, then:

```bash
docker compose up -d --build vllm-backend
```

**Refresh docs now**

```bash
bash scripts/refresh-knowledge-rag-docs.sh
```

Or fetch only (no restart):

```bash
docker compose exec docs-sync /fetch-docs.sh
```

**Wipe doc index and rebuild**

```bash
bash scripts/refresh-knowledge-rag-docs.sh --reindex
```

Or manually:

```bash
docker compose stop knowledge-rag-docs
rm -rf knowledge-rag-docs/data/*
docker compose up -d knowledge-rag-docs
```

## Troubleshooting

**vLLM exit 137 / unhealthy** — Usually OOM. Lower `--gpu-memory-utilization` or use a smaller model.

**vLLM cannot find model / HF download errors in Docker** — The HuggingFace cache is mounted **read-only** so Docker cannot download or modify `~/.cache/huggingface`. Pre-download on the host: `hf download Qwen/Qwen3.6-35B-A3B-FP8`. Do not run Docker vLLM and native `vlm` against the same cache concurrently.

**knowledge-rag-docs unreachable from Mac** — SSH tunnel must be running on port 8179.

**knowledge-rag-docs GPU embeddings** — `config.yaml` sets `models.embedding.gpu: true`; the image installs `knowledge-rag[server,gpu]`. Compose passes one NVIDIA device (shares the GPU with vLLM). After rebuild, logs should show CUDA providers; if not, it falls back to CPU with a `[WARN]`. vLLM uses `--gpu-memory-utilization 0.7`; if embedding indexing OOMs, lower vLLM utilization or switch to `bge-small-en-v1.5` (384D).

**Headroom issues** — Headroom runs locally; see [../local/README.md](../local/README.md).

## Logs

```bash
docker compose logs -f vllm-backend knowledge-rag-docs docs-sync
```
