#!/bin/bash

#==============================================================================
# Script to Fix Patch Path Issues for prplOS
#==============================================================================

echo "=== Patch Path Issue Fixer ==="
echo "This script will help identify and fix patch path issues"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment if available
if [ -f "$HOME/.prplos-env" ]; then
    source "$HOME/.prplos-env"
fi

# Set defaults
WORKSPACE="${PRPLOS_WORKSPACE:-$HOME/prplos-workspace}"
SOURCE_DIR="${PRPLOS_SOURCE:-$HOME/build/prplos-workspace/prplos}"
PATCH_DIR="${PRPLOS_PATCH_DIR:-$WORKSPACE/patches}"

echo "Current Configuration:"
echo "  Source Directory: $SOURCE_DIR"
echo "  Patch Directory: $PATCH_DIR"
echo ""

# Function to analyze a patch file
analyze_patch() {
    local patch_file=$1
    local patch_name=$(basename "$patch_file")
    
    echo -e "${BLUE}Analyzing: $patch_name${NC}"
    
    # Extract the files this patch tries to modify
    local target_files=$(grep -E "^\+\+\+|^---" "$patch_file" | grep -v "/dev/null" | awk '{print $2}' | sed 's/^[ab]\///' | sort | uniq)
    
    echo "  Files this patch tries to modify:"
    local missing_count=0
    local found_count=0
    
    while IFS= read -r file; do
        # Skip empty lines
        [ -z "$file" ] && continue
        
        # Try different path combinations
        local found=false
        
        # Check absolute path first
        if [ -f "$SOURCE_DIR/$file" ]; then
            echo -e "    ${GREEN}✓${NC} $file (found at: $SOURCE_DIR/$file)"
            found=true
            found_count=$((found_count + 1))
        else
            # Try to find the file anywhere in source
            local search_result=$(find "$SOURCE_DIR" -name "$(basename "$file")" -type f 2>/dev/null | head -1)
            if [ -n "$search_result" ]; then
                local relative_path=${search_result#$SOURCE_DIR/}
                echo -e "    ${YELLOW}⚠${NC} $file (found at different path: $relative_path)"
                found=true
            else
                echo -e "    ${RED}✗${NC} $file (NOT FOUND)"
                missing_count=$((missing_count + 1))
            fi
        fi
    done <<< "$target_files"
    
    echo "  Summary: $found_count found, $missing_count missing"
    echo ""
    
    return $missing_count
}

# Function to test different patch levels
test_patch_levels() {
    local patch_file=$1
    local patch_name=$(basename "$patch_file")
    
    echo -e "${BLUE}Testing patch levels for: $patch_name${NC}"
    
    cd "$SOURCE_DIR" || {
        echo -e "${RED}Cannot change to source directory${NC}"
        return 1
    }
    
    # Test different -p levels
    for p_level in 0 1 2 3 4; do
        echo -n "  Testing -p$p_level: "
        if patch --dry-run -p$p_level < "$patch_file" &>/dev/null; then
            echo -e "${GREEN}SUCCESS${NC}"
            echo -e "  ${GREEN}→ Use -p$p_level for this patch${NC}"
            return 0
        else
            echo -e "${RED}FAILED${NC}"
        fi
    done
    
    echo -e "  ${RED}No suitable patch level found${NC}"
    return 1
}

# Function to create a patch fixer script
create_patch_fixer() {
    local output_script="$WORKSPACE/apply-patches-fixed.sh"
    
    cat > "$output_script" << 'EOF'
#!/bin/bash
# Fixed patch application script

source ~/.prplos-env

cd "$PRPLOS_SOURCE" || exit 1

echo "Applying patches with corrected paths..."

# Function to apply a single patch with the correct level
apply_patch_smart() {
    local patch_file=$1
    local patch_name=$(basename "$patch_file")
    
    echo "Applying: $patch_name"
    
    # Try different patch levels
    for p_level in 1 0 2 3; do
        if patch --dry-run -p$p_level < "$patch_file" &>/dev/null; then
            echo "  Using -p$p_level"
            patch -p$p_level < "$patch_file"
            return $?
        fi
    done
    
    echo "  ERROR: Could not apply patch"
    return 1
}

# Apply all patches
for patch in "$PRPLOS_PATCH_DIR"/*.patch; do
    [ -f "$patch" ] || continue
    apply_patch_smart "$patch" || {
        echo "Failed to apply: $(basename "$patch")"
        # Continue with other patches
    }
done

echo "Patch application complete!"
EOF
    
    chmod +x "$output_script"
    echo -e "${GREEN}Created fixed patch script: $output_script${NC}"
}

# Main diagnostic flow
echo "=== Step 1: Checking Source Directory Structure ==="
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}ERROR: Source directory not found: $SOURCE_DIR${NC}"
    echo "Please update PRPLOS_SOURCE in ~/.prplos-env"
    exit 1
fi

echo "Source directory contents:"
ls -la "$SOURCE_DIR" | head -10
echo ""

# Check for common prplOS/OpenWrt directories
echo "Looking for key directories:"
for dir in package target toolchain scripts feeds; do
    if [ -d "$SOURCE_DIR/$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir/"
    else
        echo -e "  ${RED}✗${NC} $dir/ (not found)"
    fi
done
echo ""

echo "=== Step 2: Analyzing Patches ==="
if [ ! -d "$PATCH_DIR" ]; then
    echo -e "${RED}ERROR: Patch directory not found: $PATCH_DIR${NC}"
    exit 1
fi

# Analyze each patch
total_patches=0
problematic_patches=0

for patch in "$PATCH_DIR"/*.patch; do
    [ -f "$patch" ] || continue
    total_patches=$((total_patches + 1))
    
    analyze_patch "$patch"
    if [ $? -ne 0 ]; then
        problematic_patches=$((problematic_patches + 1))
        
        # Test different patch levels
        test_patch_levels "$patch"
        echo ""
    fi
done

echo "=== Step 3: Summary ==="
echo "Total patches analyzed: $total_patches"
echo "Problematic patches: $problematic_patches"
echo ""

if [ $problematic_patches -gt 0 ]; then
    echo -e "${YELLOW}Some patches have path issues.${NC}"
    echo ""
    echo "Possible solutions:"
    echo "1. The patches might be created from a different directory level"
    echo "2. Your source tree might be missing some components"
    echo "3. The patches might be for a different version of prplOS"
    echo ""
    
    create_patch_fixer
    echo ""
    echo "Try running: $WORKSPACE/apply-patches-fixed.sh"
else
    echo -e "${GREEN}All patches appear to have correct paths!${NC}"
fi

echo ""
echo "=== Additional Diagnostics ==="
echo "To see what a patch expects, examine it:"
echo "  head -20 $PATCH_DIR/005-UCI-Default-Values-Update.patch"
echo ""
echo "To find where files actually are:"
echo "  find $SOURCE_DIR -name 'uci.c' -o -name '*.mk' | grep -E '(build|dhcp|kernel|web)'"