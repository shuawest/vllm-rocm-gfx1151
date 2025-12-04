#!/bin/bash
set -e

# Load Pinned Versions
if [ -f "versions.env" ]; then
    source versions.env
else
    echo "ERROR: versions.env not found!"
    exit 1
fi

# Configuration Overrides (Environment variables take precedence)
IMAGE_NAME="${IMAGE_NAME:-strix-vllm}"
TAG="${TAG:-$IMAGE_TAG}"
DOCKERFILE="${DOCKERFILE:-Dockerfile.fedora}"  # Default to Fedora (RH-aligned)
TEST_ONLY=false
NO_CACHE=false
ENGINE="podman" # Default to podman for Red Hat alignment

# Help function
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --test-only     Run smoke tests on existing image"
    echo "  --no-cache      Build without cache"
    echo "  --tag <tag>     Specify image tag (default: $TAG)"
    echo "  --docker        Use docker instead of podman"
    echo "  --help          Show this help message"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --test-only) TEST_ONLY=true ;;
        --no-cache) NO_CACHE=true ;;
        --tag) TAG="$2"; shift ;;
        --docker) ENGINE="docker" ;;
        --help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

build_image() {
    echo "====== Building Container Image: ${FULL_IMAGE_NAME} ======"
    echo "Engine: ${ENGINE}"
    echo "ROCm Index: ${ROCM_INDEX_URL}"
    echo "Torch Version: ${TORCH_VERSION}"
    echo "vLLM Commit: ${VLLM_COMMIT}"
    echo "Flash Attn Commit: ${FLASH_ATTENTION_COMMIT}"

    BUILD_ARGS=(
        --build-arg ROCM_INDEX_URL="${ROCM_INDEX_URL}"
        --build-arg TORCH_VERSION="${TORCH_VERSION}"
        --build-arg TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION}"
        --build-arg TORCHVISION_VERSION="${TORCHVISION_VERSION}"
        --build-arg VLLM_REPO="${VLLM_REPO}"
        --build-arg VLLM_COMMIT="${VLLM_COMMIT}"
        --build-arg FLASH_ATTENTION_REPO="${FLASH_ATTENTION_REPO}"
        --build-arg FLASH_ATTENTION_COMMIT="${FLASH_ATTENTION_COMMIT}"
        --build-arg PYTHON_VERSION="${PYTHON_VERSION}"
    )

    if [ "$NO_CACHE" = true ]; then
        BUILD_ARGS+=(--no-cache)
    fi

    $ENGINE build -t "${FULL_IMAGE_NAME}" -f "${DOCKERFILE}" "${BUILD_ARGS[@]}" .
}

run_smoke_test() {
    echo "====== Running Smoke Test ======"
    
    # Check for /dev/kfd availability (ROCm)
    DEVICE_ARGS=""
    if [ -e "/dev/kfd" ]; then
        DEVICE_ARGS="--device=/dev/kfd --device=/dev/dri --group-add video --security-opt seccomp=unconfined"
    else
        echo "WARNING: ROCm devices not found. Running in CPU-only mode (might fail if vLLM expects GPU)."
    fi

    $ENGINE run --rm -it \
        $DEVICE_ARGS \
        --shm-size=16g \
        "${FULL_IMAGE_NAME}" \
        python3 /opt/vllm-build/scripts/smoke_test.py
}

# Main execution flow
LOG_FILE="build_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Logging to: $LOG_FILE"

{
    if [ "$TEST_ONLY" = true ]; then
        run_smoke_test
    else
        build_image
        run_smoke_test
    fi
    echo "====== Build Pipeline Completed Successfully ======"
} 2>&1 | tee "$LOG_FILE"

