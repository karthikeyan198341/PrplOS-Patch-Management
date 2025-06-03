#!/bin/bash
# fix-prplos-build-environment.sh
# Fixes prplOS build environment, missing dependencies, and patch issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in prplOS directory
check_prplos_dir() {
    if [ ! -f "feeds.conf.default" ] && [ ! -f "feeds.conf" ]; then
        print_error "Not in prplOS root directory!"
        print_info "Please run this script from the prplOS source directory"
        print_info "Example: cd ~/prplos-workspace/prplos && ../scripts/fix-prplos-build-environment.sh"
        return 1
    fi
    return 0
}

# Fix feeds configuration
fix_feeds_config() {
    print_info "Fixing feeds configuration..."
    
    # Backup existing feeds.conf if it exists
    if [ -f "feeds.conf" ]; then
        cp feeds.conf feeds.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Check if feeds.conf.default exists
    if [ -f "feeds.conf.default" ]; then
        print_info "Using feeds.conf.default as base"
        cp feeds.conf.default feeds.conf
    else
        print_warning "No feeds.conf.default found, creating basic feeds configuration"
        cat > feeds.conf << 'EOF'
src-git packages https://git.openwrt.org/feed/packages.git
src-git luci https://git.openwrt.org/project/luci.git
src-git routing https://git.openwrt.org/feed/routing.git
src-git telephony https://git.openwrt.org/feed/telephony.git
EOF
    fi
    
    # Add additional feeds if needed for libpam
    if ! grep -q "oldpackages" feeds.conf 2>/dev/null; then
        print_info "Adding oldpackages feed for legacy dependencies"
        echo "src-git oldpackages https://git.openwrt.org/archive/packages.git" >> feeds.conf
    fi
    
    print_success "Feeds configuration updated"
}

# Clean and update feeds
update_feeds() {
    print_info "Cleaning and updating package feeds..."
    
    # Clean feed directories
    print_info "Cleaning old feeds..."
    ./scripts/feeds clean -a || true
    
    # Update all feeds
    print_info "Updating feeds (this may take a while)..."
    ./scripts/feeds update -a || {
        print_error "Feed update failed!"
        print_info "Trying alternative approach..."
        
        # Try updating feeds one by one
        for feed in packages luci routing telephony; do
            print_info "Updating feed: $feed"
            ./scripts/feeds update $feed || print_warning "Failed to update $feed"
        done
    }
    
    print_success "Feeds updated"
}

# Install all packages from feeds
install_feeds() {
    print_info "Installing packages from feeds..."
    
    # Install all packages
    ./scripts/feeds install -a || {
        print_warning "Some packages failed to install"
        
        # Try to install specific problematic packages
        print_info "Installing specific packages..."
        for pkg in libpam pam pam-devel; do
            ./scripts/feeds install $pkg 2>/dev/null || true
        done
    }
    
    # Install missing dependencies
    print_info "Checking for missing dependencies..."
    ./scripts/feeds install libpam || print_warning "libpam not found in feeds"
    
    print_success "Feed packages installed"
}

# Fix configuration for missing packages
fix_config() {
    print_info "Fixing build configuration..."
    
    # Create a minimal working config if none exists
    if [ ! -f ".config" ]; then
        print_info "No .config found, creating minimal configuration"
        cat > .config << 'EOF'
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
# Disable packages that require libpam if libpam is not available
# CONFIG_PACKAGE_lldpd is not set
# CONFIG_PACKAGE_policycoreutils is not set
EOF
    fi
    
    # Disable problematic packages if libpam is not available
    print_info "Adjusting configuration for available packages..."
    
    # Make olddefconfig to set defaults
    make defconfig || make oldconfig || true
    
    # If libpam is still missing, disable packages that depend on it
    if ! ./scripts/feeds list | grep -q "^libpam "; then
        print_warning "libpam not available, disabling dependent packages"
        
        # Disable packages that require libpam
        sed -i 's/CONFIG_PACKAGE_lldpd=y/# CONFIG_PACKAGE_lldpd is not set/g' .config
        sed -i 's/CONFIG_PACKAGE_policycoreutils=y/# CONFIG_PACKAGE_policycoreutils is not set/g' .config
        
        # Add these to .config if not present
        echo "# CONFIG_PACKAGE_lldpd is not set" >> .config
        echo "# CONFIG_PACKAGE_policycoreutils is not set" >> .config
    fi
    
    print_success "Configuration adjusted"
}

# Download sources
download_sources() {
    print_info "Downloading package sources..."
    
    # This helps prevent issues during build
    make download || {
        print_warning "Some downloads failed, continuing anyway"
    }
    
    print_success "Source download complete"
}

# Clean build environment
clean_build_env() {
    print_info "Cleaning build environment..."
    
    # Clean specific problematic packages
    for pkg in netifd busybox lldpd policycoreutils; do
        make package/$pkg/clean V=s 2>/dev/null || true
    done
    
    # Clean tmp
    rm -rf tmp/
    
    print_success "Build environment cleaned"
}

# Prepare specific package for patching
prepare_package_for_patch() {
    local package=$1
    
    print_info "Preparing $package for patching..."
    
    # Clean the package first
    make package/$package/clean V=s || true
    
    # Prepare with QUILT
    make package/$package/prepare V=s QUILT=1 || {
        print_error "Failed to prepare $package"
        print_info "Trying without QUILT..."
        make package/$package/prepare V=s || return 1
    }
    
    print_success "$package prepared for patching"
    return 0
}

# Updated patch automation wrapper
create_fixed_automation_wrapper() {
    print_info "Creating fixed automation wrapper..."
    
    local wrapper_script="$HOME/prplos-workspace/scripts/run-prplos-automation-fixed.sh"
    
    cat > "$wrapper_script" << 'EOF'
#!/bin/bash
# Fixed wrapper for prplOS automation that handles dependencies properly

# Set environment
export PRPLOS_ROOT="${PRPLOS_ROOT:-$HOME/prplos-workspace/prplos}"
export LOG_DIR="${LOG_DIR:-$HOME/prplos-workspace/logs}"
export RESULTS_DIR="${RESULTS_DIR:-$HOME/prplos-workspace/results}"
export PATCHES_DIR="${PATCHES_DIR:-$HOME/prplos-workspace/patches}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Ensure directories exist
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$PATCHES_DIR"

# Check if prplOS is properly set up
if [ ! -d "$PRPLOS_ROOT" ]; then
    print_error "prplOS not found at $PRPLOS_ROOT"
    exit 1
fi

cd "$PRPLOS_ROOT"

# Check if feeds are installed
if [ ! -d "feeds" ] || [ ! -f "feeds.conf" ]; then
    print_error "Feeds not configured! Run fix-prplos-build-environment.sh first"
    exit 1
fi

# For apply command, ensure package is prepared first
if [ "$1" = "apply" ] && [ $# -ge 4 ]; then
    method=$2
    package=$3
    patch=$4
    
    print_info "Ensuring $package is prepared before patching..."
    
    # Clean and prepare the package
    make package/$package/clean V=s 2>/dev/null || true
    
    # Try to prepare with QUILT
    if ! make package/$package/prepare V=s QUILT=1 2>/dev/null; then
        print_error "Failed to prepare $package with QUILT"
        print_info "Trying standard prepare..."
        make package/$package/prepare V=s || {
            print_error "Failed to prepare $package"
            print_error "Package might not exist or have unmet dependencies"
            exit 1
        }
    fi
fi

# Activate Python virtual environment if available
if [ -f "$HOME/prplos-venv/bin/activate" ]; then
    source "$HOME/prplos-venv/bin/activate"
fi

# Run the actual automation script
if [ -f "$HOME/prplos-workspace/scripts/prplos-patch-automation-suite.sh" ]; then
    exec "$HOME/prplos-workspace/scripts/prplos-patch-automation-suite.sh" "$@"
else
    print_error "prplos-patch-automation-suite.sh not found!"
    exit 1
fi
EOF
    
    chmod +x "$wrapper_script"
    print_success "Fixed wrapper created at: $wrapper_script"
}

# Main fix process
main() {
    print_info "=== prplOS Build Environment Fix ==="
    
    # Check if we're in the right directory
    if ! check_prplos_dir; then
        # Try to find prplOS directory
        if [ -d "$HOME/prplos-workspace/prplos" ]; then
            print_info "Found prplOS at ~/prplos-workspace/prplos"
            cd "$HOME/prplos-workspace/prplos"
        else
            print_error "Cannot find prplOS directory"
            exit 1
        fi
    fi
    
    PRPLOS_ROOT=$(pwd)
    print_info "Working in: $PRPLOS_ROOT"
    
    # Step 1: Fix feeds
    fix_feeds_config
    
    # Step 2: Update feeds
    update_feeds
    
    # Step 3: Install feeds
    install_feeds
    
    # Step 4: Fix configuration
    fix_config
    
    # Step 5: Clean build environment
    clean_build_env
    
    # Step 6: Download sources (optional but recommended)
    read -p "Download package sources now? (recommended) [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        download_sources
    fi
    
    # Step 7: Create fixed wrapper
    create_fixed_automation_wrapper
    
    # Test preparation of common packages
    print_info "Testing package preparation..."
    for pkg in netifd firewall dnsmasq; do
        if prepare_package_for_patch $pkg; then
            print_success "$pkg can be patched"
        else
            print_warning "$pkg preparation failed"
        fi
    done
    
    print_success "=== Build environment fix complete ==="
    print_info "Next steps:"
    print_info "1. Use the fixed wrapper script:"
    print_info "   ~/prplos-workspace/scripts/run-prplos-automation-fixed.sh setup"
    print_info "2. Try applying patches to working packages (netifd, firewall, dnsmasq)"
    print_info "3. Avoid packages with missing dependencies (lldpd, policycoreutils) until fixed"
    print_info ""
    print_info "Example:"
    print_info "   cd ~/prplos-workspace"
    print_info "   ./scripts/run-prplos-automation-fixed.sh apply quilt netifd patches/001-network-enhancement.patch"
}

# Run main
main "$@"