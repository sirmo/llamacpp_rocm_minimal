#!/bin/bash

# llama-server configuration for Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL
# Translated from Kobold configuration

# Model settings
# Auto-detect model path (supports both direct mount and symlink resolution)
MODEL_BASE_PATH="${MODEL_BASE_PATH:-/models}"
MODEL_PATH="${MODEL_BASE_PATH}/cerebras_MiniMax-M2-REAP-162B-A10B-Q3_K_M-00001-of-00002.gguf"
PORT=5001
HOST="0.0.0.0"

# Context and batch settings
CONTEXT_SIZE=100000
BATCH_SIZE=128

# Thread settings
THREADS=8
THREADS_BATCH=32

# GPU settings
GPU_LAYERS=200

# Default sampling settings
TEMPERATURE=0.6
TOP_P=0.95
TOP_K=20
MIN_P=0.5
MAX_TOKENS=28000
FREQUENCY_PENALTY=1.1

# Navigate to llama.cpp bin directory
cd /app/llama.cpp/build/bin

# Run llama-server with equivalent settings
./llama-server \
  --model "${MODEL_PATH}" \
  --port ${PORT} \
  --host ${HOST} \
  --ctx-size ${CONTEXT_SIZE} \
  --batch-size ${BATCH_SIZE} \
  --threads ${THREADS} \
  --threads-batch ${THREADS_BATCH} \
  --n-gpu-layers ${GPU_LAYERS} \
  --temp ${TEMPERATURE} \
  --top-p ${TOP_P} \
  --top-k ${TOP_K} \
  --min-p ${MIN_P} \
  --n-predict ${MAX_TOKENS} \
  --repeat-penalty ${FREQUENCY_PENALTY} \
  --no-mmap \
  --jinja \
  --n-predict -1 \
  --flash-attn on \
  --cache-type-k q4_0 --cache-type-v q4_0 \
  --parallel 1 \
  -v

# Kobold config mapping:
# - model_param -> --model
# - port_param -> --port
# - contextsize -> --ctx-size
# - blasbatchsize -> --batch-size
# - threads -> --threads
# - blasthreads -> --threads-batch
# - gpulayers -> --n-gpu-layers
# - ropeconfig[1] -> --rope-freq-base (10000.0)
# - multiuser -> --parallel 4 (allows multiple concurrent requests)
# - nommap=false -> --no-mmap (disabled mmap as per kobold config)
