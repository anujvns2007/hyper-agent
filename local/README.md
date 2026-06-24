# Local MCP Stack (MacBook)

Docker Compose services that need **direct access to your source tree**. Run these on the machine where you code (typically your MacBook).

## Services

| Service | Port | MCP URL | Purpose |
|---------|------|---------|---------|
| **serena-mcp** | 5050 | `http://127.0.0.1:5050/sse` | Symbol navigation, definitions, structured edits |
| **code-graph-mcp** | 5070 | `http://127.0.0.1:5070/sse` | Call-graph / structure intelligence |
| **knowledge-rag-code** | 8180 | `http://127.0.0.1:8180/sse` | Semantic search over your repo |

## Quick start

```bash
cd local
cp .env.example .env
# Edit .env — set PROJECT_ROOT to your repo (or parent dir for serena multi-project)

docker compose up -d --build
docker compose ps
```

## PROJECT_ROOT

| Service | Recommended `PROJECT_ROOT` |
|---------|---------------------------|
| **serena-mcp** | Parent of repos, e.g. `~/work/repo` — activate one project per Cursor chat |
| **code-graph-mcp** | Single repo, e.g. `~/work/repo/hyper-agent` |
| **knowledge-rag-code** | Single repo (same as code-graph) |

Serena activation (start of each Cursor chat):

> Activate Serena project hyper-agent at `/workspaces/projects/hyper-agent`

Paths inside Serena use container paths under `/workspaces/projects/`.

## Cursor MCP config

```json
{
  "mcpServers": {
    "serena": { "url": "http://127.0.0.1:5050/sse" },
    "code-graph": { "url": "http://127.0.0.1:5070/sse" },
    "knowledge-rag-code": { "url": "http://127.0.0.1:8180/sse" }
  }
}
```

## Verify

```bash
docker compose ps                                    # all Up, code-graph healthy
docker inspect code-graph-mcp knowledge-rag-code \
  --format '{{.Name}} restarts={{.RestartCount}}'   # restarts should be 0
curl -s -o /dev/null -w "serena: %{http_code}\n" --max-time 3 http://127.0.0.1:5050/sse
python3 -c "import socket; [socket.create_connection(('127.0.0.1',p),2).close() or print(f'port {p}: ok') for p in (5070,8180)]"
```

## Layout

```
local/
├── docker-compose.yaml
├── .env.example
├── serena-mcp/           # Serena MCP (built from GitHub)
├── code-graph-mcp/       # codebase-memory-mcp + supergateway
│   └── data/             # graph index cache (gitignored)
└── knowledge-rag-code/   # semantic index of PROJECT_ROOT
    ├── config.yaml
    └── data/             # vectors + model cache (gitignored)
```

## Troubleshooting

**code-graph-mcp restart loop** — Do not health-check `/sse` (supergateway allows only one SSE client). The compose file uses a TCP port probe.

**knowledge-rag-code restart loop (exit 75)** — Stale PID lock from Docker restarts. The entrypoint clears it automatically; if stuck: `rm knowledge-rag-code/data/knowledge-rag.lock`.

**Slow or OOM indexing** — Point `PROJECT_ROOT` at one repo, not your entire `~/work/repo` tree.

**Re-index from scratch**

```bash
docker compose stop code-graph-mcp
rm -rf code-graph-mcp/data/*
docker compose up -d code-graph-mcp

docker compose stop knowledge-rag-code
rm -rf knowledge-rag-code/data/*
docker compose up -d knowledge-rag-code
```

## Logs

```bash
docker compose logs -f serena-mcp code-graph-mcp knowledge-rag-code
```
