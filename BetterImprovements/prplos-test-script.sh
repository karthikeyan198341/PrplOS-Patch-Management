#!/bin/bash

#==============================================================================
# Diagnostic Script for prplOS Patch Issues
#==============================================================================

echo "=== prplOS Patch Automation Diagnostics ==="
echo "Running diagnostics to identify issues..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: Script availability
echo "1. Checking for automation script..."
if [ -f "prplos-patch-automation-suite.sh" ]; then
    echo -e "${GREEN}✓${NC} prplos-patch-automation-suite.sh found"
    if [ -x "prplos-patch-automation-suite.sh" ]; then
        echo -e "${GREEN}✓${NC} Script is executable"
    else
        echo -e "${RED}✗${NC} Script is not executable"
        echo "  Fix: chmod +x prplos-patch-automation-suite.sh"
    fi
else
    echo -e "${RED}✗${NC} prplos-patch-automation-suite.sh NOT FOUND"
    echo "  You need to save the script from the artifact first!"
fi

# Check 2: Environment
echo ""
echo "2. Checking environment variables..."
if [ -f "$HOME/.prplos-env" ]; then
    echo -e "${GREEN}✓${NC} Environment file exists"
    source "$HOME/.prplos-env"
    echo "   PRPLOS_WORKSPACE: $PRPLOS_WORKSPACE"
    echo "   PRPLOS_SOURCE: $PRPLOS_SOURCE"
else
    echo -e "${YELLOW}⚠${NC} No environment file found"
fi

# Check 3: Directory structure
echo ""
echo "3. Checking directory structure..."
WORKSPACE="${PRPLOS_WORKSPACE:-$HOME/prplos-workspace}"
for dir in patches backups logs results build; do
    if [ -d "$WORKSPACE/$dir" ]; then
        echo -e "${GREEN}✓${NC} $WORKSPACE/$dir exists"
    else
        echo -e "${YELLOW}⚠${NC} $WORKSPACE/$dir missing (will be created)"
    fi
done

# Check 4: Patches
echo ""
echo "4. Checking for patch files..."
PATCH_COUNT=$(find "${WORKSPACE}/patches" -name "*.patch" -o -name "*.diff" 2>/dev/null | wc -l)
if [ "$PATCH_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Found $PATCH_COUNT patch file(s)"
    echo "   Patches:"
    find "${WORKSPACE}/patches" -name "*.patch" -o -name "*.diff" | sort | while read patch; do
        echo "   - $(basename "$patch")"
    done
else
    echo -e "${YELLOW}⚠${NC} No patches found in ${WORKSPACE}/patches"
fi

# Check 5: Source directory
echo ""
echo "5. Checking source directory..."
SOURCE_DIR="${PRPLOS_SOURCE:-/opt/prplos/source}"
if [ -d "$SOURCE_DIR" ]; then
    echo -e "${GREEN}✓${NC} Source directory exists: $SOURCE_DIR"
    if [ -f "$SOURCE_DIR/Makefile" ] || [ -f "$SOURCE_DIR/makefile" ]; then
        echo -e "${GREEN}✓${NC} Makefile found"
    else
        echo -e "${YELLOW}⚠${NC} No Makefile found in source directory"
    fi
else
    echo -e "${RED}✗${NC} Source directory not found: $SOURCE_DIR"
    echo "  Update PRPLOS_SOURCE in ~/.prplos-env"
fi

# Check 6: Required tools
echo ""
echo "6. Checking required tools..."
for tool in patch make tar; do
    if command -v $tool &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool is installed"
    else
        echo -e "${RED}✗${NC} $tool is NOT installed"
    fi
done

# Check 7: The issue from your log
echo ""
echo "7. Checking for common issues from your log..."
if [ -d "$HOME/prplos-workspace/prplos/scripts" ]; then
    echo -e "${YELLOW}⚠${NC} Found old workspace structure"
    echo "  Your patches might be in: $HOME/prplos-workspace/prplos/scripts/patches/"
    echo "  Copy them to: ${WORKSPACE}/patches/"
fi

# Summary
echo ""
echo "=== Diagnostic Summary ==="
if [ -f "prplos-patch-automation-suite.sh" ] && [ "$PATCH_COUNT" -gt 0 ] && [ -d "$SOURCE_DIR" ]; then
    echo -e "${GREEN}✓ System appears ready for patch automation${NC}"
    echo ""
    echo "Next steps:"
    echo "1. source ~/.prplos-env"
    echo "2. ./prplos-patch-automation-suite.sh setup"
    echo "3. ./prplos-patch-automation-suite.sh apply --dry-run  # Test first"
    echo "4. ./prplos-patch-automation-suite.sh apply            # Apply patches"
else
    echo -e "${RED}✗ System needs configuration${NC}"
    echo ""
    echo "Issues to fix:"
    [ ! -f "prplos-patch-automation-suite.sh" ] && echo "- Save the prplos-patch-automation-suite.sh script"
    [ "$PATCH_COUNT" -eq 0 ] && echo "- Add patches to ${WORKSPACE}/patches/"
    [ ! -d "$SOURCE_DIR" ] && echo "- Set correct PRPLOS_SOURCE in ~/.prplos-env"
fi
echo ""