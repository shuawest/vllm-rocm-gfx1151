#!/bin/bash
set -e

# Wrapper to run the Ansible playbook
# Usage: ./run_setup.sh [target_host]

TARGET="${1:-localhost}"
USER_HOST=""

if [ "$TARGET" != "localhost" ]; then
    USER_HOST="-i $TARGET,"
else
    USER_HOST="-i localhost, --connection=local"
fi

echo "Running setup on $TARGET..."

# Check if ansible-playbook is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible not found. Installing..."
    if [ -f /etc/fedora-release ]; then
        sudo dnf install -y ansible
    elif [ -f /etc/debian_version ]; then
        sudo apt-get install -y ansible
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ansible
    else
        echo "Please install ansible manually."
        exit 1
    fi
fi

ansible-playbook setup.yml $USER_HOST
