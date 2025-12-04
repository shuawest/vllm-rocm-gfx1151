#!/bin/bash
# Setup passwordless sudo for build automation
# WARNING: This grants passwordless sudo for specific commands.
# Run this script ONCE on the aimax host with your password.

set -e

echo "====== Passwordless Sudo Setup for Build Automation ======"
echo ""
echo "This script will configure passwordless sudo for:"
echo "  - dnf (package manager)"
echo "  - usermod (group management)"
echo ""
echo "Security Note: This is scoped to ONLY the commands needed for setup."
echo "You will need to enter your password ONCE to set this up."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Get current user
USER=$(whoami)
SUDOERS_FILE="/etc/sudoers.d/build-automation"

# Create sudoers entry
SUDOERS_CONTENT="# Passwordless sudo for build automation
# Created: $(date)
# User: $USER

# Package management for build dependencies
$USER ALL=(ALL) NOPASSWD: /usr/bin/dnf

# User/group management for ROCm device access
$USER ALL=(ALL) NOPASSWD: /usr/sbin/usermod

# Optional: Allow all podman/docker commands without password
# $USER ALL=(ALL) NOPASSWD: /usr/bin/podman
# $USER ALL=(ALL) NOPASSWD: /usr/bin/docker
"

echo ""
echo "Creating sudoers file: $SUDOERS_FILE"
echo "---"
echo "$SUDOERS_CONTENT"
echo "---"
echo ""

# Create the sudoers file
echo "$SUDOERS_CONTENT" | sudo tee "$SUDOERS_FILE" > /dev/null

# Set correct permissions (sudoers files must be 0440)
sudo chmod 0440 "$SUDOERS_FILE"

# Validate the sudoers file
if sudo visudo -c -f "$SUDOERS_FILE" > /dev/null 2>&1; then
    echo "✅ Sudoers file created and validated successfully!"
    echo ""
    echo "You can now run the following commands without a password:"
    echo "  - sudo dnf install <package>"
    echo "  - sudo usermod -aG <group> <user>"
    echo ""
    echo "To test:"
    echo "  sudo -n dnf --version"
else
    echo "❌ ERROR: Invalid sudoers syntax!"
    sudo rm -f "$SUDOERS_FILE"
    exit 1
fi

echo ""
echo "Passwordless sudo setup complete!"
