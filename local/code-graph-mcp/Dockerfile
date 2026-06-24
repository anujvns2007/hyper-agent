FROM node:20-bookworm-slim

ARG CBM_VERSION=v0.8.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && npm install -g supergateway \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      amd64) CBM_ARCH=linux-amd64 ;; \
      arm64) CBM_ARCH=linux-arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL \
      "https://github.com/DeusData/codebase-memory-mcp/releases/download/${CBM_VERSION}/codebase-memory-mcp-${CBM_ARCH}-portable.tar.gz" \
      | tar -xz -C /usr/local/bin codebase-memory-mcp \
    && chmod +x /usr/local/bin/codebase-memory-mcp

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
EXPOSE 5070

ENTRYPOINT ["/entrypoint.sh"]
