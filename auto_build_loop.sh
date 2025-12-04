#!/bin/bash
set -e

# Automated Build Loop with Error Detection
# This script syncs, builds, fetches logs, and reports errors

REMOTE_HOST="aimax"
REMOTE_DIR="~/aimax_build"
LOCAL_DIR="$(pwd)"
LOG_DIR="./logs"

echo "====== Automated Build Loop ======"
echo "Remote: $REMOTE_HOST:$REMOTE_DIR"
echo ""

# Step 1: Sync files
echo "[1/4] Syncing files to remote..."
rsync -avz --exclude .git --exclude .venv --exclude logs . "$REMOTE_HOST:$REMOTE_DIR/"
echo ""

# Step 2: Run build
echo "[2/4] Starting remote build..."
echo "NOTE: This will run in the background. Waiting 2 minutes before checking logs..."
ssh "$REMOTE_HOST" "cd $REMOTE_DIR && nohup ./build_pipeline.sh > build.out 2>&1 &"
echo ""

# Wait for build to make progress
echo "[3/4] Waiting for build to progress (2 minutes)..."
sleep 120

# Step 3: Fetch logs
echo "[4/4] Fetching logs..."
./fetch_logs.sh
echo ""

# Step 4: Analyze latest log
LATEST_LOG=$(ls -t $LOG_DIR/build_log_*.txt | head -1)
echo "====== Latest Log: $LATEST_LOG ======"
echo ""

# Check for errors
if grep -q "Error:" "$LATEST_LOG"; then
    echo "❌ BUILD FAILED"
    echo ""
    echo "Latest error:"
    grep -A 3 "Error:" "$LATEST_LOG" | tail -4
    echo ""
    echo "Full error context (last 30 lines):"
    tail -30 "$LATEST_LOG"
    exit 1
elif grep -q "Build Pipeline Completed Successfully" "$LATEST_LOG"; then
    echo "✅ BUILD SUCCEEDED!"
    echo ""
    echo "Final output:"
    tail -20 "$LATEST_LOG"
    exit 0
else
    echo "⏳ BUILD IN PROGRESS"
    echo ""
    echo "Last 20 lines of log:"
    tail -20 "$LATEST_LOG"
    echo ""
    echo "Run './fetch_logs.sh' to check again, or re-run this script."
    exit 2
fi
