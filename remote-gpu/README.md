# Remote GPU Stack

Docker Compose services that run on a **Linux GPU host**: local LLM inference (vLLM), Headroom compression proxy, and a searchable index of **public documentation**.

Your Mac connects via **SSH tunnel** — see [../README.md](../README.md).

## Services

| Service | Port | Purpose |
|---------|------|---------|
| **vllm-backend** | 8000 | OpenAI-compatible LLM (Qwen3.6-35B-A3B-FP8) |
| **headroom-proxy** | 8787 | Routes LLM traffic; **code-aware** AST compression |
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
docker logs headroom-ai        # Code-Aware: ENABLED
```

First vLLM startup can take several minutes.

## MacBook tunnel

From your laptop (keep this session open while coding):

```bash
ssh -N \
  -L 8787:127.0.0.1:8787 \
  -L 8179:127.0.0.1:8179 \
  user@gpu-host
```

Optional `~/.ssh/config`:

```
Host gpu-agent
  HostName gpu-host.example.com
  User your-user
  LocalForward 8787 127.0.0.1:8787
  LocalForward 8179 127.0.0.1:8179
```

## Codex (MacBook) — `~/.codex/config.toml`

Codex **does not** reliably use `OPENAI_BASE_URL` for custom/local providers. Configure `model_providers` in TOML instead.

```bash
# On Mac (from this repo)
mkdir -p ~/.codex
cp codex.config.example.toml ~/.codex/config.toml
cp codex.hyper-agent.config.example.toml ~/.codex/hyper-agent.config.toml
export OPENAI_API_KEY=dummy    # name must match env_key in config.toml

# Tunnel (8787 = Headroom, 8000 = optional direct vLLM debug)
ssh -N -L 8787:127.0.0.1:8787 -L 8000:127.0.0.1:8000 user@gpu-host

codex --profile hyper-agent
```

**Profile settings** (`hyper-agent.config.toml`):

| Key | Value | Why |
|-----|-------|-----|
| `model_provider` | `headroom` | Routes via tunneled Headroom → vLLM |
| `model` | `Qwen/Qwen3.6-35B-A3B-FP8` | Must match vLLM served name |
| `wire_api` | `responses` | Required for Codex tool loop (in base config) |
| `approval_policy` | `never` | No approval prompts (trusted dev machine) |
| `sandbox_mode` | `danger-full-access` | Shell/file tools run without sandbox limits |

Use `127.0.0.1`, not `localhost` (avoids IPv6 `/v1/responses` streaming issues).

**Debug tool calling** — switch profile to direct vLLM (bypass Headroom):

```toml
# in ~/.codex/hyper-agent.config.toml
model_provider = "vllm-direct"
```

vLLM is started with `--enable-auto-tool-choice` and `--tool-call-parser qwen3_coder` so Codex gets structured tool calls instead of raw `<tool_call>` text.

## Claude Code (via tunnel)

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:8787
export ENABLE_TOOL_SEARCH=true
claude
```

## Cursor MCP (tunneled docs)

```json
{
  "mcpServers": {
    "knowledge-rag-docs": { "url": "http://127.0.0.1:8179/sse" }
  }
}
```

## Verify

```bash
# On GPU host
curl -s http://127.0.0.1:8787/livez
curl -s http://127.0.0.1:8000/v1/models

# On Mac (tunnel must be up)
curl -s -o /dev/null -w "docs-rag: %{http_code}\n" --max-time 3 http://127.0.0.1:8179/sse
```

## Layout

```
remote-gpu/
├── docker-compose.yaml
├── .env.example
├── codex.config.example.toml           # → ~/.codex/config.toml (Mac)
├── codex.hyper-agent.config.example.toml  # → ~/.codex/hyper-agent.config.toml
├── headroom/                  # Headroom + code-aware patch
└── knowledge-rag-docs/
    ├── config.yaml
    ├── fetch-docs-manifest.tsv
    ├── fetch-docs.sh
    ├── documents/             # downloaded docs (gitignored)
    └── data/                  # vector index (gitignored)
```

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

## Customization

**Change LLM model** — edit `vllm-backend.command` in `docker-compose.yaml`, then:

```bash
docker compose up -d --build vllm-backend headroom-proxy
```

**Refresh docs now**

```bash
docker compose exec docs-sync /fetch-docs.sh
```

**Wipe doc index and rebuild**

```bash
docker compose stop knowledge-rag-docs
rm -rf knowledge-rag-docs/data/*
docker compose up -d knowledge-rag-docs
```

## Troubleshooting

**vLLM exit 137 / unhealthy** — Usually OOM. Lower `--gpu-memory-utilization` or use a smaller model.

**vLLM cannot find model / HF download errors in Docker** — The HuggingFace cache is mounted **read-only** so Docker cannot download or modify `~/.cache/huggingface`. Pre-download on the host: `hf download Qwen/Qwen3.6-35B-A3B-FP8`. Do not run Docker vLLM and native `vlm` against the same cache concurrently.

**Headroom unhealthy** — Waits for vLLM. Check `docker logs vllm-qwen3.6` first.

**knowledge-rag-docs unreachable from Mac** — SSH tunnel must be running on ports 8787 and 8179.

## Logs

```bash
docker compose logs -f vllm-backend headroom-proxy knowledge-rag-docs docs-sync
```
