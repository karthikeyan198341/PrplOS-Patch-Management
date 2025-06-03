#!/bin/bash

#==============================================================================
# Quick Setup Script for prplOS Patch Automation
#==============================================================================

echo "=== prplOS Patch Automation Setup ==="
echo "This script will help you set up and debug the patch automation"
echo ""

# Step 1: Download the correct script
echo "Step 1: Downloading the prplos-patch-automation-suite.sh..."
if [ -f "prplos-patch-automation-suite.sh" ]; then
    echo "✓ Script already exists"
else
    echo "✗ Script not found. Please save the prplos-patch-automation-suite.sh from the previous artifact"
    echo "  Make sure to copy the ENTIRE script content"
    exit 1
fi

# Step 2: Make it executable
echo ""
echo "Step 2: Making script executable..."
chmod +x prplos-patch-automation-suite.sh
echo "✓ Done"

# Step 3: Check environment
echo ""
echo "Step 3: Checking your environment..."
echo "Current directory: $(pwd)"
echo "Home directory: $HOME"
echo "User: $(whoami)"

# Step 4: Set up default directories
echo ""
echo "Step 4: Setting up default workspace..."
DEFAULT_WORKSPACE="$HOME/prplos-workspace"
mkdir -p "$DEFAULT_WORKSPACE"/{patches,backups,logs,results,build}
echo "✓ Created workspace at: $DEFAULT_WORKSPACE"

# Step 5: Check for patches
echo ""
echo "Step 5: Looking for patch files..."
if [ -d "$HOME/prplos-workspace/prplos/scripts/patches" ]; then
    echo "Found patches at: $HOME/prplos-workspace/prplos/scripts/patches"
    echo "Copying patches to default location..."
    cp -v $HOME/prplos-workspace/prplos/scripts/patches/*.patch "$DEFAULT_WORKSPACE/patches/" 2>/dev/null || echo "No .patch files found"
    cp -v $HOME/prplos-workspace/prplos/scripts/patches/*.diff "$DEFAULT_WORKSPACE/patches/" 2>/dev/null || echo "No .diff files found"
elif [ -d "./patches" ]; then
    echo "Found patches in current directory"
    cp -v ./patches/*.patch "$DEFAULT_WORKSPACE/patches/" 2>/dev/null || echo "No .patch files found"
    cp -v ./patches/*.diff "$DEFAULT_WORKSPACE/patches/" 2>/dev/null || echo "No .diff files found"
else
    echo "⚠ No patches directory found"
    echo "  Please place your patches in: $DEFAULT_WORKSPACE/patches/"
fi

echo ""
echo "Patches in workspace:"
ls -la "$DEFAULT_WORKSPACE/patches/" 2>/dev/null || echo "No patches found"

# Step 6: Set up environment variables
echo ""
echo "Step 6: Creating environment configuration..."
cat > "$HOME/.prplos-env" << EOF
# prplOS Patch Automation Environment
export PRPLOS_WORKSPACE="$DEFAULT_WORKSPACE"
export PRPLOS_SOURCE="$HOME/prplos-workspace/prplos"  # Adjust this to your source
export PRPLOS_PATCH_DIR="$DEFAULT_WORKSPACE/patches"
export PRPLOS_BACKUP_DIR="$DEFAULT_WORKSPACE/backups"
export PRPLOS_LOG_DIR="$DEFAULT_WORKSPACE/logs"
export PRPLOS_RESULTS_DIR="$DEFAULT_WORKSPACE/results"
export PRPLOS_BUILD_DIR="$DEFAULT_WORKSPACE/build"
export PRPLOS_PATCH_LEVEL="1"
export PRPLOS_DRY_RUN="false"
export PRPLOS_PARALLEL_JOBS="4"
EOF
echo "✓ Created environment file: $HOME/.prplos-env"

# Step 7: Test the script
echo ""
echo "Step 7: Testing the automation script..."
echo "Loading environment..."
source "$HOME/.prplos-env"

echo ""
echo "Running setup command..."
./prplos-patch-automation-suite.sh setup

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To use the patch automation suite:"
echo ""
echo "1. First, load the environment:"
echo "   source ~/.prplos-env"
echo ""
echo "2. Check available patches:"
echo "   ls -la $DEFAULT_WORKSPACE/patches/"
echo ""
echo "3. Run patch automation:"
echo "   ./prplos-patch-automation-suite.sh --help       # Show help"
echo "   ./prplos-patch-automation-suite.sh apply        # Apply all patches"
echo "   ./prplos-patch-automation-suite.sh full         # Full automation"
echo ""
echo "4. View results:"
echo "   firefox $DEFAULT_WORKSPACE/results/patch_report_*.html"
echo ""
echo "If you encounter issues:"
echo "- Check the log file in: $DEFAULT_WORKSPACE/logs/"
echo "- Ensure your source directory is correct in ~/.prplos-env"
echo "- Verify patch files are in the correct format"
echo ""