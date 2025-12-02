#!/bin/bash

# llama-server configuration for Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL
# Translated from Kobold configuration

# Model settings
# Auto-detect model path (supports both direct mount and symlink resolution)
MODEL_BASE_PATH="${MODEL_BASE_PATH:-/home/md/models}"
MODEL_PATH="${MODEL_BASE_PATH}/Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf"
PORT=5001
HOST="0.0.0.0"

# Context and batch settings
CONTEXT_SIZE=200000
BATCH_SIZE=128

# Thread settings
THREADS=8
THREADS_BATCH=8

# GPU settings
GPU_LAYERS=200

# RoPE settings
# Qwen 2.5 uses a huge base, trust the GGUF default (usually 1000000), 
# but override the SCALE to compress context.
ROPE_FREQ_BASE=1000000.0  
ROPE_FREQ_SCALE=0.125     # 32k / 256k = 0.125 (Linear Scaling)

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
  --rope-freq-base ${ROPE_FREQ_BASE} \
  --no-mmap \
  --jinja \
  --chat-template-file run/templates/qwen3coder.jinja \
  --model-draft ${MODEL_BASE_PATH}Qwen3-0.6B-UD-Q6_K_XL.gguf \
  -v \
  --parallel 1

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
