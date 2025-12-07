# Makefile for llama-cpp-gfx1151 Docker image management
ROCM_GPU_ARCH ?= gfx1151

# Detect if NO_CACHE goal is passed
NO_CACHE := $(filter NO_CACHE,$(MAKECMDGOALS))

# Image names
IMAGE_NAME := llama-cpp-$(ROCM_GPU_ARCH)
EXPORT_DIR := ./images

# Model base path - single source of truth for model location
MODEL_BASE_PATH ?= /models

# Build arguments
LLAMACPP_BRANCH ?= master
LLAMACPP_FORK_URL ?= https://github.com/ggml-org/llama.cpp.git
ROCM_VERSION ?= 7.1.1.70101-1

# Import environment overrides if set
export LLAMACPP_BRANCH
export LLAMACPP_FORK_URL
ROCM_PATH_VERSION ?= 7.1.1
UBUNTU_VERSION ?= jammy

MINIMAL_IMAGE_NAME := llamacpp_rocm_${ROCM_GPU_ARCH}.minimal

.PHONY: help build build-log minimal minimal-script clean-containers clean-images save-image save-image-zst save-minimal-image save-minimal-image-zst compare-exports run run-original list ls version upload load-image load-minimal-image clean-exports clean full-clean all

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build \
		$(if $(NO_CACHE),--no-cache,) \
		--build-arg ROCM_VERSION=$(ROCM_VERSION) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg ROCM_GPU_ARCH=$(ROCM_GPU_ARCH) \
		--build-arg LLAMACPP_BRANCH=${LLAMACPP_BRANCH} \
		--build-arg LLAMACPP_FORK_URL=${LLAMACPP_FORK_URL} \
		-t $(IMAGE_NAME) .

minimal: ## Create minimal image (~1.4GB) using Dockerfile.minimal
	@echo "Building minimal image from full image..."
	@echo "NOTE: Requires 'make build' to be run first"
	docker build -f Dockerfile.minimal \
		--build-arg ROCM_VERSION=$(ROCM_PATH_VERSION) \
		--build-arg ROCM_GPU_ARCH=$(ROCM_GPU_ARCH) \
		-t $(MINIMAL_IMAGE_NAME) .

save-minimal-image: ## Save the minimal image to disk (uncompressed)
	@mkdir -p $(EXPORT_DIR)
	@echo "Saving $(MINIMAL_IMAGE_NAME) to $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar..."
	docker save $(MINIMAL_IMAGE_NAME) -o $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar
	@echo "Minimal image saved successfully!"
	@ls -lh $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar

save-minimal-image-zst: ## Save the minimal image to disk (zstd compressed)
	@mkdir -p $(EXPORT_DIR)
	@echo "Saving $(MINIMAL_IMAGE_NAME) to $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst..."
	docker save $(MINIMAL_IMAGE_NAME) | zstd -T0 > $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst
	@echo "Minimal image saved successfully!"
	@ls -lh $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst

load-minimal-image: ## Load the minimal image from disk
	@if [ -f "$(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst" ]; then \
		echo "Loading $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst..."; \
		zstd -d -c $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar.zst | docker load; \
	elif [ -f "$(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar" ]; then \
		echo "Loading $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar..."; \
		docker load -i $(EXPORT_DIR)/$(MINIMAL_IMAGE_NAME).tar; \
	else \
		echo "Error: No saved minimal image found"; \
		exit 1; \
	fi
	@echo "Minimal image loaded successfully!"

list: ## List all available model scripts (without .sh extension)
	@echo "Available model scripts:"
	@ls -1 run/*.sh | xargs -n1 basename | sed 's/\.sh$$//' | sed 's/^/  /'

ls: ## Alias for list target
	@$(MAKE) list

version: ## Display llama-cpp server version using minimal container
	@echo "Checking llama-cpp server version..."
	@docker run --rm $(MINIMAL_IMAGE_NAME) ./llama-server --version 2>&1 | grep -E "(version:|built with)" || echo "Version check failed - ensure minimal image is built"

upload: ## Upload the minimal Docker image to Docker Hub via upload.sh script, using llama version as tag
	@chmod +x ./upload.sh
	@LLAMA_VERSION=$$(docker run --rm $(MINIMAL_IMAGE_NAME) ./llama-server --version 2>&1 | grep '^version:' | awk '{print $$2}' | cut -d'(' -f1); \
	if [ -z "$$LLAMA_VERSION" ]; then echo "Failed to get llama version"; exit 1; fi; \
	IMAGE_TAG="$(ROCM_PATH_VERSION)-$$LLAMA_VERSION" MINIMAL_IMAGE_NAME=$(MINIMAL_IMAGE_NAME) ./upload.sh

save-image: ## Save the original image to disk
	@mkdir -p $(EXPORT_DIR)
	@echo "Saving $(IMAGE_NAME) to $(EXPORT_DIR)/$(IMAGE_NAME).tar..."
	docker save $(IMAGE_NAME) -o $(EXPORT_DIR)/$(IMAGE_NAME).tar
	@echo "Image saved successfully!"
	@ls -lh $(EXPORT_DIR)/$(IMAGE_NAME).tar

save-image-zst: ## Save the original image (zstd compressed)
	@mkdir -p $(EXPORT_DIR)
	@echo "Saving $(IMAGE_NAME) to $(EXPORT_DIR)/$(IMAGE_NAME).tar.zst..."
	docker save $(IMAGE_NAME) | zstd -T0 > $(EXPORT_DIR)/$(IMAGE_NAME).tar.zst
	@echo "Image saved successfully!"
	@ls -lh $(EXPORT_DIR)/$(IMAGE_NAME).tar.zst

load-image: ## Load the original image from disk
	@echo "Loading $(EXPORT_DIR)/$(IMAGE_NAME).tar..."
	docker load -i $(EXPORT_DIR)/$(IMAGE_NAME).tar
	@echo "Image loaded successfully!"

compare-docker: ## Show Docker image sizes (original only)
	@echo "Docker image size comparison (original):"
	@echo "====================="
	@docker images | grep -E "REPOSITORY|$(IMAGE_NAME)" | grep -v grep

compare-exports: ## Compare saved image archive sizes in $(EXPORT_DIR)
	@echo "Exported image file size comparison:"
	@echo "====================="
	@ls -lh $(EXPORT_DIR)/*.tar* 2>/dev/null || echo "No exported images found."

run: ## Run model script via wrapper (usage: make run gpt-oss-120B)
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Usage: make run <model-script-name>"; \
		echo "Available scripts:"; \
		ls -1 run/*.sh | xargs -n1 basename | sed 's/\.sh$$//' | sed 's/^/  /'; \
		exit 1; \
	fi
	@SCRIPT_NAME="$(filter-out $@,$(MAKECMDGOALS))"; \
	MODEL_BASE_PATH=$(MODEL_BASE_PATH) ROCM_GPU_ARCH=$(ROCM_GPU_ARCH) ./run_wrapper.sh $$SCRIPT_NAME

# Catch-all target to prevent make from complaining about unknown targets
%:
	@:

clean-images: ## Remove all llama-cpp images (original and minimal)
	@echo "Removing llama-cpp images..."
	-docker rmi $(IMAGE_NAME) $(MINIMAL_IMAGE_NAME) 2>/dev/null || true

clean-exports: ## Remove exported image files
	@echo "Removing exported images..."
	rm -rf $(EXPORT_DIR)

clean: clean-containers clean-exports ## Clean up containers and exported images

full-clean: clean clean-images ## Complete cleanup including Docker images

# Workflow targets
all: build minimal save-minimal-image  ## Build, create minimal image, save it
