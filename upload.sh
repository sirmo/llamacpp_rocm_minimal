#!/bin/bash

# --- Interactive configuration ---
read -p "Enter your Docker Hub username: " DOCKER_USERNAME
read -s -p "Enter your Docker Hub access token (input hidden): " DOCKER_TOKEN
echo ""
read -p "Enter the target repository name on Docker Hub (e.g., myrepo): " REPO_NAME
if [ -z "$IMAGE_TAG" ]; then
  read -p "Enter image tag (default 'latest'): " IMAGE_TAG_INPUT
  IMAGE_TAG=${IMAGE_TAG_INPUT:-latest}
else
  echo "Using provided IMAGE_TAG: $IMAGE_TAG"
fi

# Path to minimal image tar saved by make save-minimal-image
EXPORT_DIR="./images"
# Determine the minimal image name from Makefile variable if available, fallback to default
if [ -z "${MINIMAL_IMAGE_NAME}" ]; then
  MINIMAL_IMAGE_NAME="llama-cpp-gfx1151.minimal"
fi
MINIMAL_IMAGE_TAR="$EXPORT_DIR/${MINIMAL_IMAGE_NAME}.tar"

# Load the image if not already present locally
if ! docker images | grep -q "${MINIMAL_IMAGE_NAME}"; then
  if [ -f "$MINIMAL_IMAGE_TAR" ]; then
    echo "Loading minimal image from $MINIMAL_IMAGE_TAR..."
    docker load -i "$MINIMAL_IMAGE_TAR"
  else
    echo "Minimal image tar not found at $MINIMAL_IMAGE_TAR. Please run 'make save-minimal-image' first."
    exit 1
  fi
fi

# --- Login to Docker Hub using token ---
echo "Logging into Docker Hub..."
printf "%s\n" "$DOCKER_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin
if [ $? -ne 0 ]; then
  echo "Docker login failed. Exiting."
  exit 1
fi

# --- Tag the Docker image ---
TARGET_IMAGE_FULL_TAG="$DOCKER_USERNAME/$REPO_NAME:$IMAGE_TAG"
echo "Tagging image '$MINIMAL_IMAGE_NAME' as '$TARGET_IMAGE_FULL_TAG'..."
docker tag "$MINIMAL_IMAGE_NAME" "$TARGET_IMAGE_FULL_TAG"
if [ $? -ne 0 ]; then
  echo "Docker tagging failed. Exiting."
  exit 1
fi

# --- Push the Docker image to Docker Hub ---
echo "Pushing image '$TARGET_IMAGE_FULL_TAG' to Docker Hub..."
docker push "$TARGET_IMAGE_FULL_TAG"
if [ $? -ne 0 ]; then
  echo "Docker push failed. Exiting."
  exit 1
fi

echo "Successfully pushed Docker image '$TARGET_IMAGE_FULL_TAG' to Docker Hub."

# --- Also tag and push as 'latest' ---
if [ "$IMAGE_TAG" != "latest" ]; then
  LATEST_TAG="$DOCKER_USERNAME/$REPO_NAME:latest"
  echo "Tagging image as '$LATEST_TAG'..."
  docker tag "$MINIMAL_IMAGE_NAME" "$LATEST_TAG"
  if [ $? -ne 0 ]; then
    echo "Docker tagging for 'latest' failed. Exiting."
    exit 1
  fi

  echo "Pushing image '$LATEST_TAG' to Docker Hub..."
  docker push "$LATEST_TAG"
  if [ $? -ne 0 ]; then
    echo "Docker push for 'latest' failed. Exiting."
    exit 1
  fi

  echo "Successfully pushed Docker image '$LATEST_TAG' to Docker Hub."
fi
