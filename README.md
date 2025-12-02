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

As you add your own specific model run scripts you can list them running `make list`.


## Build Your Own Docker Image

```sh
export ROCM_GPU_ARCH=gfx1100  # 7900xtx
make build
```

```sh
make minimal
```
This will take a long time.

Optionally, save locally and upload to Docker Hub:
```sh
make save-minimal-image
```

Interactive shell will ask for: DockerHub username, token and repo
```sh
make upload
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

---

## Contributing & License
Feel free to open issues or submit pull requests for improvements. The Dockerfiles and scripts are provided under the MIT license.
