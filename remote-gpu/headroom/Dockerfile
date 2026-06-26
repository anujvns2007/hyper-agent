FROM ghcr.io/chopratejas/headroom:latest

# AST-based code compression (--code-aware). Operates on code in request/response
# bodies in transit; does not need the repo mounted in this container.
RUN pip install --no-cache-dir "headroom-ai[code]"
