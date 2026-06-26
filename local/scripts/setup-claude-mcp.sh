#!/usr/bin/env bash
# Configure Claude Code for this stack via ~/.claude/settings.json.
#
# Assumes:
#   - local/ containers (Headroom, code-graph) are running
#   - remote-gpu (vLLM, knowledge-rag-docs) runs on a remote GPU host
#   - SSH port forwarding for vLLM and docs RAG:
#       ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host
#
# Usage:
#   bash local/scripts/setup-claude-mcp.sh
#   HEADROOM_URL=http://127.0.0.1:8787 bash local/scripts/setup-claude-mcp.sh
#
set -euo pipefail

HEADROOM_URL="${HEADROOM_URL:-http://127.0.0.1:8787}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-headroom-local}"
MODEL="${ANTHROPIC_MODEL:-qwen3.6}"
USER_SETTINGS="${CLAUDE_USER_SETTINGS:-$HOME/.claude/settings.json}"

log() { printf '==> %s\n' "$*"; }

write_user_settings() {
  log "Writing $USER_SETTINGS"
  python3 - <<'PY' "$USER_SETTINGS" "$HEADROOM_URL" "$ANTHROPIC_API_KEY" "$MODEL"
import json, os, sys

path, headroom, api_key, model = sys.argv[1:5]

data = {}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

env = data.setdefault("env", {})
env.update({
    "ANTHROPIC_BASE_URL": headroom,
    "ANTHROPIC_API_KEY": api_key,
    "ANTHROPIC_DEFAULT_OPUS_MODEL": model,
    "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": model,
    "ANTHROPIC_MODEL": model,
    "ANTHROPIC_SMALL_FAST_MODEL": model,
    "ENABLE_TOOL_SEARCH": "false",
})

perms = data.setdefault("permissions", {})
perms["defaultMode"] = "bypassPermissions"
perms["skipDangerousModePermissionPrompt"] = True

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

verify_headroom() {
  if curl -sf "${HEADROOM_URL%/}/livez" >/dev/null 2>&1; then
    echo "  Headroom reachable at $HEADROOM_URL"
    return 0
  fi
  echo "  Warning: Headroom not reachable at $HEADROOM_URL" >&2
  echo "  Start local stack: cd local && docker compose up -d --build" >&2
  echo "  Ensure vLLM tunnel is up for Headroom upstream:" >&2
  echo "    ssh -N -L 8000:127.0.0.1:8000 -L 8179:127.0.0.1:8179 user@gpu-host" >&2
  return 1
}

main() {
  write_user_settings
  log "Verifying local Headroom..."
  verify_headroom || true

  cat <<EOF

Done. Claude Code user settings written to:
  $USER_SETTINGS

Start a session from the repo root:
  claude

Register MCP servers separately (global user scope):
  claude mcp add serena -s user -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --project-from-cwd --enable-web-dashboard false --open-web-dashboard false --log-level ERROR
  claude mcp add --transport http code-graph http://127.0.0.1:5070/mcp -s user
  claude mcp add --transport http knowledge-rag-docs http://127.0.0.1:8179/mcp -s user
EOF
}

main "$@"
