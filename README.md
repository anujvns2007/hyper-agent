# Agent — Local + Remote GPU Stack

Docker Compose setup for coding agents (Claude Code, Codex) with **inference on a GPU host** and **code-aware tools on your MacBook**.

Your source code stays on the Mac. The Mac runs Headroom (code-aware compression + code-graph), MCP servers, and repo indexes. The GPU machine runs vLLM and a searchable index of **public documentation**.

## Architecture

```mermaid
flowchart TB
  subgraph mac["MacBook — local/"]
    IDE["Claude Code / Codex"]
    SER["Serena (native uvx stdio)"]
    HR["headroom-proxy :8787"]
    KRC["knowledge-rag-code :8180"]
    REPO["PROJECT_ROOT"]
    CG["code-graph-mcp :5070"]

    REPO --> SER
    REPO --> KRC
    REPO --> CG
    REPO --> HR
    IDE --> SER
    IDE --> KRC
    IDE --> CG
    IDE --> HR
  end

  subgraph tunnel["SSH tunnel"]
    T8000[":8000"]
    T8179[":8179"]
  end

  subgraph gpu["GPU host — remote-gpu/"]
    VLLM["vLLM :8000"]
    KRD["knowledge-rag-docs :8179"]
    SYNC["docs-sync"]

    SYNC --> KRD
  end

  HR --> T8000
  IDE --> T8179
  T8000 --> VLLM
  T8179 --> KRD
```

**Design principle:** GPU for compute, Mac for filesystem and Headroom code-graph.

## Repository layout

```
agent/
├── README.md                 ← you are here
├── local/                    ← run on MacBook (Headroom + MCP + code indexes)
│   ├── README.md
│   ├── docker-compose.yaml
│   ├── headroom/
│   ├── code-graph-mcp/
│   └── knowledge-rag-code/
└── remote-gpu/               ← run on Linux GPU host (LLM + docs)
    ├── README.md
    ├── docker-compose.yaml
    └── knowledge-rag-docs/
```

## Quick start

### 1. GPU host

```bash
cd remote-gpu
cp .env.example .env
docker compose up -d --build
```

See [remote-gpu/README.md](remote-gpu/README.md) for details, ports, and troubleshooting.

### 2. MacBook

```bash
cd local
cp .env.example .env
# Edit PROJECT_ROOT and optionally VLLM_UPSTREAM_URL
docker compose up -d --build
```

See [local/README.md](local/README.md) for Serena (native uvx) and [remote-gpu/README.md](remote-gpu/README.md) for LLM provider settings.

### 3. SSH tunnel (Mac → GPU)

Headroom runs locally; tunnel vLLM (Headroom upstream) and docs RAG only:

```bash
ssh -N \
  -L 8000:127.0.0.1:8000 \
  -L 8179:127.0.0.1:8179 \
  user@gpu-host
```

### 3b. Codex on Mac (`~/.codex/config.toml`)

Point `model_providers.headroom.base_url` at `http://127.0.0.1:8787` (local Headroom). See [local/README.md](local/README.md).

### 4. Claude Code

Assumes local stack and SSH tunnel to remote-gpu are running:

```bash
ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host
bash local/scripts/setup-claude-mcp.sh   # writes ~/.claude/settings.json
cd /path/to/agent && claude
```

Register MCP servers in `~/.claude.json` separately (`claude mcp add ... -s user`). Serena hooks: `.claude/settings.json`.

## What runs where

| Component | Host | Port | Folder |
|-----------|------|------|--------|
| vLLM | GPU | 8000 | `remote-gpu/` |
| Headroom proxy | Mac | 8787 | `local/` |
| knowledge-rag-docs | GPU | 8179 | `remote-gpu/` |
| serena | Mac | — | native `uvx` stdio — see `local/codex.serena.example.toml` |
| code-graph-mcp | Mac | 5070 | `local/` |
| knowledge-rag-code | Mac | 8180 | `local/` |

## End-to-end smoke test

```bash
# Mac — containers stable
cd local && docker compose ps

# Mac — Headroom + MCP ports
curl -s http://127.0.0.1:8787/livez
python3 -c "import socket; socket.create_connection(('127.0.0.1',8180),2).close(); print('knowledge-rag-code: ok')"

# GPU via tunnel
curl -s http://127.0.0.1:8000/v1/models
```

Ask the agent to search your repo (`knowledge-rag-code`) and look up a library doc (`knowledge-rag-docs`).

## Further reading

- [local/README.md](local/README.md) — Headroom, Mac MCP services, PROJECT_ROOT, troubleshooting
- [remote-gpu/README.md](remote-gpu/README.md) — vLLM, doc sync, LLM client env vars
