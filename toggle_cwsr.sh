#!/bin/bash
set -e

# Usage: ./toggle_cwsr.sh [on|off]

MODE=$1

if [[ "$MODE" != "on" && "$MODE" != "off" ]]; then
    echo "Usage: sudo $0 [on|off]"
    exit 1
fi

CONF_FILE="/etc/modprobe.d/amdgpu.conf"

# Determine value
if [[ "$MODE" == "on" ]]; then
    VAL=1
    echo "✅ Enabling CWSR (amdgpu.cwsr_enable=1)..."
else
    VAL=0
    echo "🚫 Disabling CWSR (amdgpu.cwsr_enable=0)..."
fi

# Create or update the config file
if grep -q "options amdgpu cwsr_enable" "$CONF_FILE" 2>/dev/null; then
    sudo sed -i "s/options amdgpu cwsr_enable=.*/options amdgpu cwsr_enable=$VAL/" "$CONF_FILE"
else
    echo "options amdgpu cwsr_enable=$VAL" | sudo tee -a "$CONF_FILE" > /dev/null
fi

echo "Configuration updated in $CONF_FILE:"
grep "cwsr_enable" "$CONF_FILE"

# Detect OS and regenerate initramfs
if [ -f /etc/fedora-release ]; then
    echo "📦 Detected Fedora. Regenerating initramfs with dracut..."
    sudo dracut -f
elif [ -f /etc/debian_version ]; then
    echo "📦 Detected Debian/Ubuntu. Updating initramfs..."
    sudo update-initramfs -u
else
    echo "⚠️  Unknown OS. You may need to manually regenerate your initramfs."
fi

echo ""
echo "🎉 Done! You MUST REBOOT for this change to take effect."
echo "   Run: sudo reboot"
