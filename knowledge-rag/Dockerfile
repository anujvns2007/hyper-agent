FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
    && pip install --no-cache-dir "knowledge-rag[server]==4.3.1" \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY config.yaml /app/config.yaml

EXPOSE 8179

CMD ["knowledge-rag", "--transport", "sse"]
