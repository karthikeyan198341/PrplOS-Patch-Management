#!/bin/bash

#==============================================================================
# Patch Content Inspector - Shows what files patches are trying to modify
#==============================================================================

echo "=== Patch Content Inspector ==="
echo "This will show you exactly what files your patches are trying to modify"
echo ""

# Load environment
if [ -f "$HOME/.prplos-env" ]; then
    source "$HOME/.prplos-env"
fi

PATCH_DIR="${PRPLOS_PATCH_DIR:-$HOME/prplos-workspace/patches}"
SOURCE_DIR="${PRPLOS_SOURCE:-$HOME/build/prplos-workspace/prplos}"

# Inspect each patch
for patch in "$PATCH_DIR"/*.patch; do
    [ -f "$patch" ] || continue
    
    echo "=================================================="
    echo "PATCH: $(basename "$patch")"
    echo "=================================================="
    
    # Show the header of the patch
    echo "First 30 lines of patch:"
    head -30 "$patch"
    echo ""
    
    # Extract file paths
    echo "Files this patch modifies:"
    grep -E "^(---|\+\+\+)" "$patch" | grep -v "/dev/null" | while read line; do
        echo "  $line"
    done
    echo ""
    
    # Show actual diff headers
    echo "Diff sections:"
    grep -E "^diff|^Index:" "$patch" | head -5
    echo ""
    
    read -p "Press Enter to continue to next patch (or Ctrl+C to stop)..."
    echo ""
done

echo ""
echo "=== Quick Fix Suggestions ==="
echo ""
echo "Based on common prplOS/OpenWrt structure, your patches might need:"
echo ""
echo "1. If patches show paths like 'a/package/...' or 'b/package/...'"
echo "   → Use: patch -p1 (strips the a/ or b/ prefix)"
echo ""
echo "2. If patches show full paths like '/home/user/openwrt/package/...'"
echo "   → You need to be in the right directory or use higher -p levels"
echo ""
echo "3. If your source is missing directories like 'package/', 'target/', etc."
echo "   → Your source tree might be incomplete. You may need to:"
echo "   - Clone the full prplOS/OpenWrt source"
echo "   - Run ./scripts/feeds update -a"
echo "   - Run ./scripts/feeds install -a"
echo ""
echo "To check if you have a complete source tree:"
echo "  ls -la $SOURCE_DIR/"