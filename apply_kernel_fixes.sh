#!/bin/bash
set -e

echo "🔧 Applying Kernel Fixes for Strix Halo (gfx1151)..."

# amdgpu.noretry=0: Prevents infinite retry loops on page faults (helps debugging/recovery)
# iommu=pt: Passthrough mode. Improves performance and fixes some DMA/IOMMU protection faults.
ARGS="amdgpu.noretry=0 iommu=pt"

# 2. Apply using grubby (Fedora standard)
# Calculate pages for 120GB (leaving 8GB for OS)
# 120 * 1024 * 1024 * 1024 / 4096 = 31457280
PAGES_120GB="31457280"

echo "🔧 Applying kernel fixes for Strix Halo..."
echo "   - amdgpu.noretry=0 (Prevent retry loops)"
echo "   - iommu=pt (Pass-through IOMMU)"
echo "   - amdttm.pages_limit=$PAGES_120GB (Unlock 120GB VRAM)"
echo "   - amdttm.page_pool_size=$PAGES_120GB (Unlock 120GB VRAM)"

sudo grubby --update-kernel=ALL --args="amdgpu.noretry=0 iommu=pt amdttm.pages_limit=$PAGES_120GB amdttm.page_pool_size=$PAGES_120GB"

echo "✅ Kernel arguments updated. Please REBOOT for changes to take effect."
sudo grubby --info=DEFAULT
 | grep args

echo ""
echo "⚠️  YOU MUST REBOOT FOR THESE CHANGES TO TAKE EFFECT."
echo "   Run: sudo reboot"
