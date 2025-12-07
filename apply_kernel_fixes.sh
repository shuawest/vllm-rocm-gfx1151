#!/bin/bash
set -e

echo "🔧 Applying Kernel Fixes for Strix Halo (gfx1151)..."

# 1. Define arguments
# amdgpu.noretry=0: Prevents infinite retry loops on page faults (helps debugging/recovery)
# iommu=pt: Passthrough mode. Improves performance and fixes some DMA/IOMMU protection faults.
ARGS="amdgpu.noretry=0 iommu=pt"

# 2. Apply using grubby (Fedora standard)
echo "   Adding args: $ARGS"
sudo grubby --update-kernel=ALL --args="$ARGS"

# 3. Verify
echo "✅ Done. Verifying current default kernel args:"
sudo grubby --info=DEFAULT | grep args

echo ""
echo "⚠️  YOU MUST REBOOT FOR THESE CHANGES TO TAKE EFFECT."
echo "   Run: sudo reboot"
