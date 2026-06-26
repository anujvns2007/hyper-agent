FROM python:3.11-slim-bookworm

ARG KNOWLEDGE_RAG_GPU=0

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
    && if [ "$KNOWLEDGE_RAG_GPU" = "1" ]; then \
         pip install --no-cache-dir "knowledge-rag[server,gpu]==4.3.1"; \
       else \
         pip install --no-cache-dir "knowledge-rag[server]==4.3.1"; \
       fi \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY config.yaml /app/config.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8180

ENTRYPOINT ["/entrypoint.sh"]
CMD ["knowledge-rag", "--transport", "streamable-http"]
