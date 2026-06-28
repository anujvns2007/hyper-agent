# CPU-only knowledge-rag-docs for MacBook (Docker Desktop / Linux arm64|amd64).
# Embeddings use ONNX on CPU — no CUDA. Mount documents/, data/, and config at runtime.
FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && pip install "knowledge-rag[server]==4.3.1" \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8179

ENTRYPOINT ["/entrypoint.sh"]
CMD ["knowledge-rag", "--transport", "streamable-http"]
