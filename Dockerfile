# Stage 0: Download amdgpu-install .deb (cached)
FROM ubuntu:22.04 AS rocm-download
ARG UBUNTU_VERSION=jammy
ARG ROCM_VERSION=7.1.70100-1
RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/rocm_download
RUN wget -q https://repo.radeon.com/amdgpu-install/latest/ubuntu/${UBUNTU_VERSION}/amdgpu-install_${ROCM_VERSION}_all.deb

# Stage 1: ROCm base image with all dependencies (cached layer)
FROM ubuntu:22.04 AS rocm-base

# Build arguments for easy version updates
ARG ROCM_VERSION=7.1.70100-1
ARG UBUNTU_VERSION=jammy
ARG ROCM_GPU_ARCH=gfx1151

# Prevent tzdata from prompting for timezone
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

# Set environment variables for ROCm
ENV PATH="/opt/rocm/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/rocm/lib"

WORKDIR /app

# Install all dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    libcurl4-openssl-dev \
    git \
    cmake \
    build-essential \
    libstdc++-12-dev \
    pkg-config \
    tree \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Copy downloaded .deb from download stage (avoids re-downloading)
COPY --from=rocm-download /tmp/rocm_download/amdgpu-install_${ROCM_VERSION}_all.deb /tmp/
# Install ROCm using the cached .deb
RUN apt-get update && apt-get install -y /tmp/amdgpu-install_${ROCM_VERSION}_all.deb && \
    amdgpu-install --usecase=hip,rocm --no-dkms -y && \
    rm -f /tmp/amdgpu-install_${ROCM_VERSION}_all.deb && \
    rm -rf /var/lib/apt/lists/*

# No additional apt packages; ROCm components come from the installer

# Stage 2: Build llama.cpp (this stage rebuilds when you modify it)
FROM rocm-base AS builder

WORKDIR /app

# Clone llama.cpp repository
ARG LLAMACPP_BRANCH=master
ARG LLAMACPP_FORK_URL=https://github.com/ggml-org/llama.cpp.git
RUN git clone --branch ${LLAMACPP_BRANCH} ${LLAMACPP_FORK_URL} /app/llama.cpp

WORKDIR /app/llama.cpp

# Build llama.cpp with HIP support for ${ROCM_GPU_ARCH}
RUN mkdir build && cd build && \
    cmake .. \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_HIP=ON \
    -DLLAMA_HIP_UMA=ON \
    -DCMAKE_C_COMPILER=/opt/rocm/llvm/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ \
    -DAMDGPU_TARGETS=${ROCM_GPU_ARCH} \
    -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . -j $(nproc)

# Stage 3: Final runtime image (default)
FROM rocm-base AS runtime

WORKDIR /app

# Copy built binaries from builder stage
COPY --from=builder /app/llama.cpp /app/llama.cpp

EXPOSE 8000
CMD ["/bin/bash"]
