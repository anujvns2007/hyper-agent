#!/bin/sh
set -eu

# SSE mode uses a PID lock file under data_dir. In Docker the main process is always
# PID 1, so a leftover lock from a crashed/restarted container looks "alive" and
# startup exits with code 75 in a restart loop.
LOCK="/app/data/knowledge-rag.lock"
if [ -f "$LOCK" ]; then
  echo "[knowledge-rag] removing stale lock from previous container run: $LOCK"
  rm -f "$LOCK"
fi

# CUDA 13 runtime (arm64 base): ensure ORT finds system libs from the NVIDIA image.
if [ -d /usr/local/cuda/lib64 ]; then
  CUDA_LIB="/usr/local/cuda/lib64"
  for target in /usr/local/cuda/targets/*/lib; do
    if [ -d "$target" ]; then
      CUDA_LIB="${CUDA_LIB}:${target}"
    fi
  done
  export LD_LIBRARY_PATH="${CUDA_LIB}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# nvidia-* pip wheels (amd64 [gpu] extra) install libs under site-packages/nvidia/*/lib
NVIDIA_LIB_PATH="$(python3 - <<'PY'
import glob
import site

paths = []
for root in site.getsitepackages():
    paths.extend(glob.glob(f"{root}/nvidia/*/lib"))
print(":".join(sorted(set(paths))))
PY
)"
if [ -n "$NVIDIA_LIB_PATH" ]; then
  export LD_LIBRARY_PATH="${NVIDIA_LIB_PATH}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

exec "$@"
