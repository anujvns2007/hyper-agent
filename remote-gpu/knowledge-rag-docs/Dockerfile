# Python 3.11 + knowledge-rag[gpu]. On aarch64 (e.g. GB10), ONNX GPU may be unavailable —
# knowledge-rag falls back to CPU automatically; vLLM still uses the GPU.
FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && pip install --upgrade pip \
    && pip install "knowledge-rag[server,gpu]==4.3.1" \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY config.yaml /app/config.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8179

ENTRYPOINT ["/entrypoint.sh"]
CMD ["knowledge-rag", "--transport", "streamable-http"]
