# Agent — Local + Remote GPU Stack

Docker Compose setup for coding agents (Claude Code, Codex) with **inference on a GPU host** and **code-aware tools on your MacBook**.

Your source code stays on the Mac. The Mac runs Headroom (code-aware compression + code-graph), MCP servers, repo indexes, and **public documentation RAG** (`knowledge-rag-docs`). The GPU machine runs vLLM and optionally the same docs RAG stack (CUDA embeddings) — manifest and config are shared.

## Architecture

```mermaid
flowchart TB
  subgraph mac["MacBook — local/"]
    IDE["Claude Code / Codex"]
    SER["Serena (native uvx stdio)"]
    HR["headroom-proxy :8787"]
    REPO["PROJECT_ROOT"]
    CG["code-graph-mcp :5070"]
    KRD["knowledge-rag-docs :8179\n(native)"]
    SYNC["sync-docs.sh"]

    REPO --> SER
    REPO --> CG
    REPO --> HR
    SYNC --> KRD
    IDE --> SER
    IDE --> CG
    IDE --> HR
    IDE --> KRD
  end

  subgraph tunnel["SSH tunnel"]
    T8000[":8000"]
  end

  subgraph gpu["GPU host — remote-gpu/"]
    VLLM["vLLM :8000"]
    KRDGPU["knowledge-rag-docs :8179\n(Docker, optional)"]
  end

  HR --> T8000
  T8000 --> VLLM
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
│   └── knowledge-rag-docs/
└── remote-gpu/               ← run on Linux GPU host (vLLM + optional docs RAG)
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
bash scripts/refresh-knowledge-rag-docs.sh --reindex   # first time or after manifest changes
```

See [remote-gpu/README.md](remote-gpu/README.md) for details, ports, and troubleshooting.

### 2. MacBook

```bash
cd local
cp .env.example .env
# Edit PROJECT_ROOT and optionally VLLM_UPSTREAM_URL
docker compose up -d --build

# Native docs RAG (Apple Silicon ONNX — not in Docker)
bash scripts/setup-knowledge-rag-docs.sh   # once
bash scripts/sync-docs.sh
bash scripts/run-knowledge-rag-docs.sh --background
```

See [local/README.md](local/README.md) for Serena (native uvx) and [remote-gpu/README.md](remote-gpu/README.md) for LLM provider settings.

### 3. SSH tunnel (Mac → GPU)

Headroom runs locally; tunnel vLLM only (Headroom upstream):

```bash
ssh -N -L 8000:127.0.0.1:8000 user@gpu-host
```

### 3b. Codex on Mac (`~/.codex/config.toml`)

Point `model_providers.headroom.base_url` at `http://127.0.0.1:8787` (local Headroom). See [local/README.md](local/README.md).

### 4. Claude Code

Assumes local stack and SSH tunnel to vLLM are running:

```bash
ssh -N -L 8000:127.0.0.1:8000 user@gpu-host
bash local/scripts/setup-claude-mcp.sh   # writes ~/.claude/settings.json
cd /path/to/agent && claude
```

Register MCP servers in `~/.claude.json` separately (`claude mcp add ... -s user`). Serena hooks: `.claude/settings.json`.

## What runs where

| Component | Host | Port | Folder |
|-----------|------|------|--------|
| vLLM | GPU | 8000 | `remote-gpu/` |
| knowledge-rag-docs (optional) | GPU (Docker) | 8179 | `remote-gpu/knowledge-rag-docs/` |
| Headroom proxy | Mac | 8787 | `local/` |
| knowledge-rag-docs (default) | Mac (native) | 8179 | `local/knowledge-rag-docs/` |
| serena | Mac | — | native `uvx` stdio — see `local/codex.serena.example.toml` |
| code-graph-mcp | Mac | 5070 | `local/` |

## End-to-end smoke test

```bash
# Mac — containers stable
cd local && docker compose ps

# Mac — Headroom + code-graph + docs RAG
curl -s http://127.0.0.1:8787/livez
python3 -c "import socket; socket.create_connection(('127.0.0.1',5070),2).close(); print('code-graph-mcp: ok')"
python3 -c "import socket; socket.create_connection(('127.0.0.1',8179),2).close(); print('knowledge-rag-docs: ok')"

# GPU via tunnel (vLLM)
curl -s http://127.0.0.1:8000/v1/models
```

Ask the agent to explore your repo (`code-graph`) and look up library docs (`knowledge-rag-docs`).

## Further reading

- [local/README.md](local/README.md) — Headroom, Mac MCP services, PROJECT_ROOT, troubleshooting
- [remote-gpu/README.md](remote-gpu/README.md) — vLLM, doc sync, LLM client env vars
