FROM ghcr.io/chopratejas/headroom:latest

# AST-based code compression (--code-aware). Operates on code in request/response
# bodies in transit; does not need the repo mounted in this container.
RUN pip install --no-cache-dir "headroom-ai[code]"

# vLLM rejects empty tools arrays; Headroom's PRE_SEND hook re-injects
# tools=[] after the main guard was fixed in #772.
RUN python3 - <<'PY'
from pathlib import Path

path = Path("/usr/local/lib/python3.13/site-packages/headroom/proxy/handlers/openai.py")
text = path.read_text()

old = """        if presend_event.tools is not None:
            tools = presend_event.tools
            body["tools"] = tools"""

new = """        if presend_event.tools is not None:
            tools = presend_event.tools
            if tools or _original_tools is not None:
                body["tools"] = tools
            elif "tools" in body:
                del body["tools"]"""

if old not in text:
    raise SystemExit("openai.py PRE_SEND patch target not found; upstream may have changed")

path.write_text(text.replace(old, new, 1))
print("Patched headroom openai PRE_SEND tools guard")
PY
