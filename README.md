# Minimal llama-cpp+ROCm Docker Image Build Scripts

This repository provides a small container image for running the `llama.cpp` server on AMD GPUs using ROCm. The image is based on Ubuntu Jammy and includes only the binaries and libraries required to run inference, keeping the size around 2 GB. (full image is over 30GB).

The default config targets Strix Halo / Ryzen AI Max 365. But you could try building for other AMD architectures, see *Build Your Own* section.

---

## Quick Start

```sh
docker pull introprose/llamacpp_rocm_minimal:latest
```
```sh
export MODEL_BASE_PATH=/models
```

### Clone the scripts

```sh
git clone git@github.com:sirmo/llamacpp_rocm_minimal.git
```

```
cd llamacpp_rocm_minimal
```

### gpt-oss-20B 

1. Download the model file `openai_gpt-oss-20b-MXFP4.gguf` from:
   https://huggingface.co/bartowski/openai_gpt-oss-20b-GGUF-MXFP4-Experimental/resolve/main/openai_gpt-oss-20b-MXFP4.gguf
2. Place it into the `/models` directory (or the path referenced by `MODEL_BASE_PATH`).
3. Run the container with the model:

```sh
make run gpt-oss-20B
```

### 120B (Optional)

1. Download the model file `openai_gpt-oss-120b-MXFP4.gguf` from: https://huggingface.co/bartowski/openai_gpt-oss-120b-GGUF-MXFP4-Experimental/resolve/main/openai_gpt-oss-120b-MXFP4.gguf
2. Place it into the `/models` directory.
3. Run the container with the model:

```sh
make run gpt-oss-120B
```

(this config uses the gpt-oss-20b as the draft model so both models need to be downloaded. Draft models in theiry provide a speed up via _speculatiive decoding_)

## Configuring Models

See directory `run/` which has some sample run scripts for different models. You should use them as exampels for running your own models. gpt-oss and minimax-m2 models run well on Strix Halo.

As you add your own specific model run scripts you can list them by running `make list`.


## Build Your Own Docker Image

```sh
export ROCM_GPU_ARCH=gfx1100  # 7900xtx
# Build without cache to force rebuild
make build NO_CACHE
```
This will take a long time.

You can force Docker to rebuild without cache by adding the `NO_CACHE` goal, e.g.,
```sh
make build NO_CACHE
```


## Help

```sh
make help

Usage: make [target]

Usage: make [target]

Available targets:
  help                 Show this help message
  build                Build the Docker image
  minimal              Create minimal image (~1.4GB) using Dockerfile.minimal
  save-minimal-image   Save the minimal image to disk (uncompressed)
  save-minimal-image-zst Save the minimal image to disk (zstd compressed)
  load-minimal-image   Load the minimal image from disk
  list                 List all available model scripts (without .sh extension)
  ls                   Alias for list target
  version              Display llama-cpp server version using minimal container
  upload               Upload the minimal Docker image to Docker Hub via upload.sh script, using llama version as tag
  save-image           Save the original image to disk
  save-image-zst       Save the original image (zstd compressed)
  load-image           Load the original image from disk
  compare-docker       Show Docker image sizes (original only)
  compare-exports      Compare saved image archive sizes in $(EXPORT_DIR)
  run                  Run model script via wrapper (usage: make run gpt-oss-120B)
  clean-images         Remove all llama-cpp images (original and minimal)
  clean-exports        Remove exported image files
  clean                Clean up containers and exported images
  full-clean           Complete cleanup including Docker images
  all                  Build, create minimal image, save it
```

# Gotchas

Location of the runfiles for the ROCm installer is approximately here:

https://repo.radeon.com/rocm/installer/rocm-runfile-installer/rocm-rel-7.1/ubuntu/22.04/

These versions change so this link may not work in the future. But you can always navigate to the latest version by backtracking.

Over time:

- `ROCM_VERSION` and `ROCM_PATH_VERSION` will have to be updated

- Dockerfile may need updates as new versions of ROCm come out

---

## Environment Variables

This section documents all environment variables used throughout the Makefile, Dockerfiles, and run_wrapper.sh script.

### Build-time Configuration (Makefile)

These variables control the build process and can be set when running make commands:

- **`ROCM_GPU_ARCH`** (default: `gfx1151`)
  - AMD GPU architecture target for compilation
  - Used in: Makefile line 2, Docker build args
  - Example: `export ROCM_GPU_ARCH=gfx1100` for 7900xtx

- **`MODEL_BASE_PATH`** (default: `/models`)
  - Base directory path where model files are stored
  - Used in: Makefile line 9, run_wrapper.sh line 23
  - Example: `export MODEL_BASE_PATH=/path/to/my/models`

- **`ROCM_VERSION`** (default: `7.1.1.70101-1`)
  - ROCm software version for the build
  - Used in: Makefile line 12, Dockerfile ARG

- **`ROCM_PATH_VERSION`** (default: `7.1.1`)
  - Simplified ROCm version path identifier
  - Used in: Makefile line 13, Dockerfile.minimal

- **`UBUNTU_VERSION`** (default: `jammy`)
  - Ubuntu distribution version for the base image
  - Used in: Makefile line 14, Dockerfile ARG

### Runtime Environment Variables (Docker Images)

These variables are set within the Docker containers:

#### Main Dockerfile (`llama-cpp-${ROCM_GPU_ARCH}`)

- **`DEBIAN_FRONTEND=noninteractive`**
  - Prevents interactive prompts during package installation
  - Set in: Dockerfile line 18

- **`TZ=America/New_York`**
  - Container timezone setting
  - Set in: Dockerfile line 19

- **`PATH="/opt/rocm/bin:${PATH}"`**
  - Adds ROCm binaries to system PATH
  - Set in: Dockerfile line 22

- **`LD_LIBRARY_PATH="/opt/rocm/lib"`**
  - ROCm library search path
  - Set in: Dockerfile line 23

#### Minimal Dockerfile (`llamacpp_rocm_${ROCM_GPU_ARCH}.minimal`)

- **`LD_LIBRARY_PATH=/app/llama.cpp/build/bin:/opt/rocm/lib:/opt/amdgpu/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu`**
  - Comprehensive library path for minimal image
  - Set in: Dockerfile.minimal line 110

- **`ROCM_PATH=/opt/rocm`**
  - ROCm installation base path
  - Set in: Dockerfile.minimal line 111

- **`HSA_OVERRIDE_GFX_VERSION=11.5.1`**
  - HSA runtime gfx version override (for compatibility)
  - Set in: Dockerfile.minimal line 112

- **`ROCBLAS_TENSILE_LIBPATH=/opt/rocm/lib/rocblas/library`**
  - rocBLAS Tensile library path
  - Set in: Dockerfile.minimal line 113

- **`HSA_ENABLE_SDMA=0`**
  - Disable SDMA for memory management
  - Set in: Dockerfile.minimal line 115

- **`GPU_MAX_ALLOC_PERCENT=100`**
  - Maximum GPU memory allocation percentage
  - Set in: Dockerfile.minimal line 116

- **`GPU_SINGLE_ALLOC_PERCENT=100`**
  - Single allocation maximum percentage
  - Set in: Dockerfile.minimal line 117

### Runtime Configuration (run_wrapper.sh)

These variables control container execution:

- **`MODEL_BASE_PATH`** (default: `/models`)
  - Override for model directory path
  - Used in: run_wrapper.sh line 23, passed to Docker with `-e`

- **`USE_ORIGINAL_IMAGE`** (default: `0`)
  - Set to `1` to use the full image instead of minimal
  - Used in: run_wrapper.sh line 26

- **`SKIP_PORT`** (default: `0`)
  - Set to `1` to skip port binding (`-p 5001:5001`)
  - Used in: run_wrapper.sh lines 46, 59

### Usage Examples

```bash
# Build for different GPU architecture
export ROCM_GPU_ARCH=gfx1100
make build minimal

# Use custom model path
export MODEL_BASE_PATH=/data/models
make run gpt-oss-20B

# Run with original (full) image instead of minimal
export USE_ORIGINAL_IMAGE=1
make run gpt-oss-20B

# Skip port binding for background execution
export SKIP_PORT=1
make run gpt-oss-20B
```

---

## Contributing & License
Feel free to open issues or submit pull requests for improvements. The Dockerfiles and scripts are provided under the MIT license.
