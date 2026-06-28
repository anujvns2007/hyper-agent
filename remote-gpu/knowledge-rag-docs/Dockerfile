# NVIDIA GPU embeddings via knowledge-rag + ONNX Runtime.
#
# aarch64 (GB10/DGX Spark): PyPI has no onnxruntime-gpu wheel. Use a CUDA 13 GPU build on
# nvidia/cuda cudnn-runtime (libcublasLt.so.13). Default ORT wheel targets SM121 Blackwell;
# override ORT_GPU_AARCH64_WHEEL at build time if needed.
# x86_64: python slim + knowledge-rag[gpu] (PyPI onnxruntime-gpu, CUDA 12).
ARG TARGETARCH
ARG ORT_CUDA13_INDEX=https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/ort-cuda-13-nightly/pypi/simple/
ARG ORT_GPU_AARCH64_WHEEL=https://huggingface.co/Jay0515/onnxruntime-gpu-aarch64-cuda13-sm121/resolve/main/onnxruntime_gpu-1.25.0-cp312-cp312-linux_aarch64.whl

FROM nvidia/cuda:13.0.1-cudnn-runtime-ubuntu24.04 AS base-arm64
FROM python:3.12-slim-bookworm AS base-amd64

FROM base-${TARGETARCH} AS base

ARG TARGETARCH
ARG ORT_CUDA13_INDEX
ARG ORT_GPU_AARCH64_WHEEL

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

# CUDA runtime base (arm64) ships Python 3.12 via Ubuntu; slim base (amd64) already has it.
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends python3 python3-pip curl \
      && ln -sf /usr/bin/python3 /usr/local/bin/python3 \
      && ln -sf /usr/bin/pip3 /usr/local/bin/pip3; \
    fi

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && if [ "$TARGETARCH" = "arm64" ]; then \
         pip3 install --break-system-packages "knowledge-rag[server]==4.3.1" \
         &&          pip3 install --break-system-packages \
              nvidia-cublas-cu12 \
              nvidia-cuda-runtime-cu12 \
              nvidia-cudnn-cu12 \
         && pip3 uninstall -y onnxruntime onnxruntime-gpu --break-system-packages \
         && pip3 install --break-system-packages --force-reinstall "${ORT_GPU_AARCH64_WHEEL}"; \
       else \
         pip3 install --upgrade pip \
         && pip3 install "knowledge-rag[server,gpu]==4.3.1"; \
       fi \
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
