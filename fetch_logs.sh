#!/bin/bash
set -e

# Script to fetch build logs from the remote host
# Usage: ./fetch_logs.sh [remote_host]

REMOTE_HOST="${1:-aimax}"
REMOTE_DIR="~/aimax_build"
LOCAL_LOG_DIR="./logs"

mkdir -p "$LOCAL_LOG_DIR"

echo "Fetching logs from $REMOTE_HOST:$REMOTE_DIR..."

# Use rsync to pull only .txt log files
if rsync -avz --include="build_log_*.txt" --exclude="*" "$REMOTE_HOST:$REMOTE_DIR/" "$LOCAL_LOG_DIR/"; then
    echo "Logs fetched successfully to $LOCAL_LOG_DIR"
    ls -lh "$LOCAL_LOG_DIR"
else
    echo "ERROR: Failed to fetch logs. Check SSH connection to $REMOTE_HOST."
    exit 1
fi
