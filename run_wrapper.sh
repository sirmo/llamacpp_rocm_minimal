#!/usr/bin/env bash
# Wrapper to run model scripts inside the minimal Docker container.
# Usage: ./run_wrapper.sh <script_name_without_extension> [args...]

set -euo pipefail

# Trap signals to ensure clean shutdown
cleanup() {
  echo "Shutting down container..."
  exit 0
}
trap cleanup SIGINT SIGTERM

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <model_script_name> [args...]"
  exit 1
fi

SCRIPT_NAME="$1"
shift

# Get MODEL_BASE_PATH from environment or use default
MODEL_BASE_PATH="${MODEL_BASE_PATH:-/models}"

# Select image based on USE_ORIGINAL_IMAGE env var
if [[ "${USE_ORIGINAL_IMAGE:-0}" == "1" ]]; then
  IMAGE_NAME="llama-cpp-gfx1151"
else
  IMAGE_NAME="llama-cpp-gfx1151.minimal"
fi

# Path inside the container where run scripts are mounted (read‑only)
CONTAINER_SCRIPT_PATH="/opt/rocm_llamacpp/run/${SCRIPT_NAME}.sh"

# Verify that the script exists on the host (mounted into the container)
HOST_SCRIPT_PATH="$(pwd)/run/${SCRIPT_NAME}.sh"
if [[ ! -f "$HOST_SCRIPT_PATH" ]]; then
  echo "Error: script $HOST_SCRIPT_PATH not found."
  exit 1
fi

# Docker run options – same as original create command, but using 'docker run' for one‑off execution.
# Allow skipping port binding via SKIP_PORT env var (set to 1 to skip)
# --init flag ensures proper signal handling and zombie process cleanup
# Use -it if we have a TTY, otherwise just -i
SKIP_PORT="${SKIP_PORT:-0}"
if [ -t 0 ]; then
  TTY_FLAG="-it"
else
  TTY_FLAG="-i"
fi

DOCKER_CMD=(docker run --rm $TTY_FLAG --init \
  --device /dev/kfd \
  --device /dev/dri \
  -v "${MODEL_BASE_PATH}:${MODEL_BASE_PATH}:ro" \
  -v "$(pwd)/run:/opt/rocm_llamacpp/run:ro" \
  -e MODEL_BASE_PATH="${MODEL_BASE_PATH}")
if [[ "$SKIP_PORT" != "1" ]]; then
  DOCKER_CMD+=( -p 5001:5001 )
fi
DOCKER_CMD+=( "$IMAGE_NAME" )

# Execute the script inside the container, using exec to replace the shell process
# This makes the script PID 1, ensuring proper signal handling and clean shutdown
"${DOCKER_CMD[@]}" /bin/bash -c "exec $CONTAINER_SCRIPT_PATH $*"
