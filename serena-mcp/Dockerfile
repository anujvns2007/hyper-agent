# Build Serena from source — ghcr.io/oraios/serena requires registry auth.
# Adapted from https://github.com/oraios/serena/blob/main/Dockerfile
FROM python:3.11-slim
SHELL ["/bin/bash", "-c"]

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

ARG SERENA_VERSION=v1.5.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    git \
    ssh \
    sudo \
    wget \
    zip \
    unzip \
    sed \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir pipx \
    && pipx ensurepath

ENV NVM_VERSION=0.40.3
ENV NODE_VERSION=22.18.0
RUN curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install "${NODE_VERSION}" \
    && nvm use "v${NODE_VERSION}" \
    && nvm alias default "v${NODE_VERSION}"
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/:${PATH}"
ENV PATH="${PATH}:/root/.local/bin"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain stable \
    --profile minimal \
    && rustup component add rust-analyzer

WORKDIR /workspaces/serena
RUN git clone --depth 1 --branch "${SERENA_VERSION}" https://github.com/oraios/serena.git .

ENV SERENA_HOME=/workspaces/serena/config
RUN mkdir -p "${SERENA_HOME}" \
    && cp src/serena/resources/serena_config.template.yml "${SERENA_HOME}/serena_config.yml" \
    && sed -i 's/^gui_log_window: .*/gui_log_window: False/' "${SERENA_HOME}/serena_config.yml" \
    && sed -i 's/^web_dashboard_listen_address: .*/web_dashboard_listen_address: 0.0.0.0/' "${SERENA_HOME}/serena_config.yml" \
    && sed -i 's/^web_dashboard_open_on_launch: .*/web_dashboard_open_on_launch: False/' "${SERENA_HOME}/serena_config.yml"

RUN uv venv \
    && source .venv/bin/activate \
    && uv pip install -r pyproject.toml -e .
ENV PATH="/workspaces/serena/.venv/bin:${PATH}"

ENTRYPOINT ["/bin/bash", "-c", "source .venv/bin/activate && exec \"$@\"", "--"]
