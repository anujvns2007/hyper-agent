FROM python:3.13-slim-bookworm

ARG HEADROOM_VERSION=0.27.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm \
    && npm install -g supergateway \
    && pip install --no-cache-dir "headroom-ai[proxy,code,mcp]==${HEADROOM_VERSION}" \
    && apt-get purge -y npm \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /app
EXPOSE 8787 8790

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--host", "0.0.0.0", "--port", "8787"]
