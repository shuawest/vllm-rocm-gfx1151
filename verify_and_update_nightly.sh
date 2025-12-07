#!/bin/bash
set -e

# Configuration
NIGHTLY_IMAGE="docker.io/rocm/vllm-dev:nightly"
DOCKERFILE="Dockerfile.spoof"
INFERENCE_SCRIPT="quick_inference.py"

echo "🔍 Checking for new nightly updates..."

# 1. Pull the latest nightly
podman pull $NIGHTLY_IMAGE

# 2. Run Verification (Spoof Test)
echo "🧪 Verifying inference on gfx1151 (Spoof Mode)..."
# Read python script into variable
PY_SCRIPT=$(cat $INFERENCE_SCRIPT)

if podman run --rm \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --env HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    --env ROC_ENABLE_PRE_VEGA=1 \
    $NIGHTLY_IMAGE \
    python3 -c "$PY_SCRIPT" > verification.log 2>&1; then
    
    echo "✅ Verification SUCCESS!"
    cat verification.log | grep "Generated text"
else
    echo "❌ Verification FAILED."
    cat verification.log
    exit 1
fi

# 3. Get the Digest
DIGEST=$(podman inspect --format='{{.RepoDigests}}' $NIGHTLY_IMAGE | awk -F'[@]' '{print $2}' | awk -F']' '{print $1}')
echo "🔒 Locking in digest: $DIGEST"

# 4. Update Dockerfile
# Use sed to replace the FROM line
sed -i "s|FROM docker.io/rocm/vllm-dev@.*|FROM docker.io/rocm/vllm-dev@$DIGEST|" $DOCKERFILE

# 5. Check for changes
if git diff --quiet $DOCKERFILE; then
    echo "No changes detected. Dockerfile is already up to date."
else
    echo "📝 Updating Dockerfile and pushing to repo..."
    git add $DOCKERFILE
    git commit -m "chore: update spoof-locked image to digest $DIGEST"
    git push
    echo "🚀 Changes pushed! GitHub Workflow should now publish the new image."
fi
