# Local Stack (MacBook)

Docker Compose services on your Mac: **Headroom** (code-aware + code-graph), and MCP servers that need **direct access to your source tree**.

## Serena (native uvx)

Install once:

```bash
# uvx must be on PATH (~/.local/bin)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Claude Code** — run `local/scripts/setup-claude-mcp.sh` to write Headroom/model env to `~/.claude/settings.json` and register Headroom MCP at `http://127.0.0.1:8790/mcp`. Serena hooks live in `.claude/settings.json`.

**Codex** — add `local/codex.serena.example.toml` to `~/.codex/config.toml`. Point Headroom at `http://127.0.0.1:8787` in your Codex provider config.

## Services (Docker)

| Service | Port | Purpose |
|---------|------|---------|
| **headroom-proxy** | 8787 / 8790 | LLM proxy + Headroom MCP (`/mcp`) — memory, code-graph, compress/retrieve tools |
| **code-graph-mcp** | 5070 | Call-graph MCP (HTTP) |

## Quick start

```bash
cd local
cp .env.example .env   # set PROJECT_ROOT; optional VLLM_UPSTREAM_URL
docker compose up -d --build
```

Headroom forwards to vLLM on the GPU host. Start the SSH tunnel first so `host.docker.internal:8000` reaches vLLM:

```bash
ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host
```

Or set `VLLM_UPSTREAM_URL` to a Tailscale/LAN address in `.env`.

### Headroom memory & learning

Headroom runs with `--memory --learn`: Claude, Codex, and any client using the same proxy share a persistent memory store (facts injected into context + `memory_save` / `memory_search` tools). Live traffic learning extracts repeated patterns and persists them after enough observations (default `min-evidence: 5`). Data is stored in `local/headroom/data/` (not in your repo — `/workspace` is read-only). Project scope follows `PROJECT_ROOT` via `--memory-project-root /workspace`.

## Claude Code

```bash
ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host
cd local && docker compose up -d --build
bash local/scripts/setup-claude-mcp.sh   # writes ~/.claude/settings.json
claude    # from repo root
```

See `.claude/settings.json` (Serena hooks) and `local/scripts/setup-claude-mcp.sh`.

## Codex

Add Serena via `local/codex.serena.example.toml`. Configure Headroom provider with `base_url = "http://127.0.0.1:8787"`. `knowledge-rag-docs` requires the SSH tunnel to the GPU host (port 8179).

## Troubleshooting

**Headroom unhealthy** — Check `docker logs headroom-ai`. Ensure vLLM tunnel is up (`curl -s http://127.0.0.1:8000/v1/models` from Mac host).

**Headroom cannot reach vLLM** — Default upstream is `http://host.docker.internal:8000`. On Linux (non-Docker Desktop), `extra_hosts: host-gateway` is set in compose. Verify tunnel or set `VLLM_UPSTREAM_URL` to the GPU's reachable IP.
