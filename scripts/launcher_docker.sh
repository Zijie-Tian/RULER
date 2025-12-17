#!/bin/bash
# Copyright (c) 2024, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Docker launcher script for RULER benchmark
# Usage: ./launcher_docker.sh

set -e

#############################################
# Configuration - Modify these variables
#############################################

# Docker image
IMAGE_NAME="cphsieh/ruler:0.2.3"

# GPU configuration: "all", "0", "0,1", etc.
GPUS="all"

# Model directory (host path)
MODEL_DIR="/home/zijie/models"

# Output directory for benchmark results (host path)
OUTPUT_DIR="$(pwd)/benchmark_root"

# Container name
CONTAINER_NAME="ruler-benchmark"

# Shared memory size
SHM_SIZE="16g"

# Run mode: "interactive" or "benchmark"
RUN_MODE="interactive"

# Model and benchmark (only used when RUN_MODE="benchmark")
MODEL_NAME="llama3.1-8b-chat"
BENCHMARK_NAME="synthetic"

# API Keys (optional, for cloud model APIs)
# OPENAI_API_KEY=""
# GEMINI_API_KEY=""
# AZURE_API_ID=""
# AZURE_API_SECRET=""
# AZURE_API_ENDPOINT=""

#############################################
# Script logic - Do not modify below
#############################################

# Remove existing container if exists
docker rm -f $CONTAINER_NAME 2>/dev/null || true

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${RED}Error: Docker image '$IMAGE_NAME' not found${NC}"
    echo "Build with: docker build -t $IMAGE_NAME -f docker/Dockerfile ."
    exit 1
fi

# Get current user UID and GID for file permission sync
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Build docker command
DOCKER_CMD="docker run --rm"
DOCKER_CMD="$DOCKER_CMD --gpus $GPUS"
DOCKER_CMD="$DOCKER_CMD --name $CONTAINER_NAME"
DOCKER_CMD="$DOCKER_CMD --shm-size=$SHM_SIZE"
DOCKER_CMD="$DOCKER_CMD --ipc=host"
DOCKER_CMD="$DOCKER_CMD --ulimit memlock=-1"
DOCKER_CMD="$DOCKER_CMD --ulimit stack=67108864"
DOCKER_CMD="$DOCKER_CMD --network=host"
DOCKER_CMD="$DOCKER_CMD --user $HOST_UID:$HOST_GID"
DOCKER_CMD="$DOCKER_CMD -e HOME=$HOME"

# Mount volumes
DOCKER_CMD="$DOCKER_CMD -v $HOME:$HOME"
DOCKER_CMD="$DOCKER_CMD -v $PROJECT_DIR:/workspace/RULER"
DOCKER_CMD="$DOCKER_CMD -v $MODEL_DIR:/data/models"
DOCKER_CMD="$DOCKER_CMD -v $OUTPUT_DIR:/workspace/RULER/scripts/benchmark_root"
DOCKER_CMD="$DOCKER_CMD -v /etc/passwd:/etc/passwd:ro"
DOCKER_CMD="$DOCKER_CMD -v /etc/group:/etc/group:ro"

# Environment variables - API Keys
[[ -n "${OPENAI_API_KEY:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e OPENAI_API_KEY=$OPENAI_API_KEY"
[[ -n "${GEMINI_API_KEY:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e GEMINI_API_KEY=$GEMINI_API_KEY"
[[ -n "${AZURE_API_ID:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e AZURE_API_ID=$AZURE_API_ID"
[[ -n "${AZURE_API_SECRET:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e AZURE_API_SECRET=$AZURE_API_SECRET"
[[ -n "${AZURE_API_ENDPOINT:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e AZURE_API_ENDPOINT=$AZURE_API_ENDPOINT"

# Environment variables - Proxy settings
[[ -n "${http_proxy:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e http_proxy=$http_proxy"
[[ -n "${https_proxy:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e https_proxy=$https_proxy"
[[ -n "${HTTP_PROXY:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e HTTP_PROXY=$HTTP_PROXY"
[[ -n "${HTTPS_PROXY:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e HTTPS_PROXY=$HTTPS_PROXY"
[[ -n "${no_proxy:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e no_proxy=$no_proxy"
[[ -n "${NO_PROXY:-}" ]] && DOCKER_CMD="$DOCKER_CMD -e NO_PROXY=$NO_PROXY"

# Working directory
DOCKER_CMD="$DOCKER_CMD -w /workspace/RULER/scripts"

# Print configuration
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RULER Docker Launcher${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Image:        $IMAGE_NAME"
echo "GPUs:         $GPUS"
echo "Model Dir:    $MODEL_DIR"
echo "Output Dir:   $OUTPUT_DIR"

if [[ "$RUN_MODE" == "interactive" ]]; then
    echo "Mode:         Interactive"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    $DOCKER_CMD -it $IMAGE_NAME /bin/bash
else
    echo "Mode:         Benchmark"
    echo "Model:        $MODEL_NAME"
    echo "Benchmark:    $BENCHMARK_NAME"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    $DOCKER_CMD $IMAGE_NAME bash run.sh "$MODEL_NAME" "$BENCHMARK_NAME"
fi
