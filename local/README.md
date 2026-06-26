# Local MCP Stack (MacBook)

Docker Compose services that need **direct access to your source tree**.

## Serena (native uvx)

Install once:

```bash
# uvx must be on PATH (~/.local/bin)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Claude Code** — run `local/scripts/setup-claude-mcp.sh` to write Headroom/model env to `~/.claude/settings.json` (requires SSH tunnel to remote-gpu). Serena hooks live in `.claude/settings.json`.

**Codex** — add `local/codex.serena.example.toml` to `~/.codex/config.toml`.

## Services (Docker)

| Service | Port | Purpose |
|---------|------|---------|
| **code-graph-mcp** | 5070 | Call-graph MCP (HTTP) |
| **knowledge-rag-code** | 8180 | Semantic search over repo |

## Quick start

```bash
cd local
cp .env.example .env   # set PROJECT_ROOT to repo path
docker compose up -d --build
```

## Claude Code

Assumes remote-gpu is running on the GPU host and SSH forwarding is active:

```bash
ssh -N -L 8787:127.0.0.1:8787 -L 8179:127.0.0.1:8179 user@gpu-host
bash local/scripts/setup-claude-mcp.sh   # writes ~/.claude/settings.json
claude    # from repo root
```

Start local MCP containers separately: `cd local && docker compose up -d --build`

See `.claude/settings.json` (Serena hooks) and `local/scripts/setup-claude-mcp.sh`.

## Codex

Add Serena via `local/codex.serena.example.toml` and Headroom via `remote-gpu/codex.config.example.toml`. `knowledge-rag-docs` requires the SSH tunnel to the GPU host.
