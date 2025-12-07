#!/bin/bash
set -e

echo "🔧 Setting up Systemd Services for Llama Vulkan..."

# 1. Install Service Template
sudo cp llama-vulkan@.service /etc/systemd/system/
sudo systemctl daemon-reload
echo "✅ Installed /etc/systemd/system/llama-vulkan@.service"

# 2. Create Config Directory
if [ ! -d "/etc/llama-vulkan" ]; then
    sudo mkdir -p /etc/llama-vulkan
    echo "✅ Created /etc/llama-vulkan"
fi

# 3. Create Model Data Directory
if [ ! -d "/data/models" ]; then
    echo "⚠️  /data/models does not exist. Creating it (requires sudo)..."
    sudo mkdir -p /data/models
    sudo chown $USER:$USER /data/models
    # Apply SELinux label if needed
    if command -v chcon &> /dev/null; then
        sudo chcon -Rt svirt_sandbox_file_t /data/models
    fi
    echo "✅ Created /data/models"
fi

echo "🎉 Systemd setup complete!"
echo "   Usage: sudo systemctl start llama-vulkan@<model-name>"
