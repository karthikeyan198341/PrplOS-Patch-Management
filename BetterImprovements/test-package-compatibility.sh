#!/bin/bash
# test-package-compatibility.sh
# Tests which packages can be successfully prepared for patching

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
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Test packages
NETWORK_PACKAGES=(
    "netifd"
    "firewall"
    "firewall4"
    "dnsmasq"
    "odhcpd"
    "odhcp6c"
    "uhttpd"
)

SYSTEM_PACKAGES=(
    "busybox"
    "procd"
    "ubox"
    "ubus"
    "uci"
    "rpcd"
)

PROBLEMATIC_PACKAGES=(
    "lldpd"
    "policycoreutils"
)

# Results storage
WORKING_PACKAGES=()
FAILED_PACKAGES=()

test_package() {
    local package=$1
    local category=$2
    
    echo -n "Testing $category/$package... "
    
    # Try to prepare the package
    if make package/$package/prepare V=0 QUILT=1 &>/dev/null; then
        print_success "OK"
        WORKING_PACKAGES+=("$package")
        # Clean up
        make package/$package/clean V=0 &>/dev/null
        return 0
    else
        print_error "FAILED"
        FAILED_PACKAGES+=("$package")
        return 1
    fi
}

main() {
    print_info "=== Package Compatibility Test ==="
    
    # Check if in prplOS directory
    if [ ! -f "feeds.conf.default" ] && [ ! -f "feeds.conf" ]; then
        print_error "Not in prplOS directory!"
        exit 1
    fi
    
    print_info "Testing network packages..."
    for pkg in "${NETWORK_PACKAGES[@]}"; do
        test_package "$pkg" "network"
    done
    
    echo
    print_info "Testing system packages..."
    for pkg in "${SYSTEM_PACKAGES[@]}"; do
        test_package "$pkg" "system"
    done
    
    echo
    print_info "Testing known problematic packages..."
    for pkg in "${PROBLEMATIC_PACKAGES[@]}"; do
        test_package "$pkg" "problematic"
    done
    
    # Summary
    echo
    echo "========================================"
    echo "           TEST SUMMARY"
    echo "========================================"
    echo
    
    if [ ${#WORKING_PACKAGES[@]} -gt 0 ]; then
        print_success "Working packages (${#WORKING_PACKAGES[@]}):"
        for pkg in "${WORKING_PACKAGES[@]}"; do
            echo "  ✓ $pkg"
        done
    fi
    
    echo
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        print_error "Failed packages (${#FAILED_PACKAGES[@]}):"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo "  ✗ $pkg"
        done
    fi
    
    echo
    echo "========================================"
    
    # Recommendations
    echo
    print_info "Recommendations:"
    if [ ${#WORKING_PACKAGES[@]} -gt 0 ]; then
        echo "Use these packages for patch testing:"
        echo -n "  "
        printf '%s ' "${WORKING_PACKAGES[@]}"
        echo
    fi
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo
        echo "Avoid these packages until dependencies are fixed:"
        echo -n "  "
        printf '%s ' "${FAILED_PACKAGES[@]}"
        echo
    fi
    
    # Save results
    cat > package_compatibility_report.txt << EOF
Package Compatibility Report
Generated: $(date)

Working Packages:
$(printf '%s\n' "${WORKING_PACKAGES[@]}" | sed 's/^/  - /')

Failed Packages:
$(printf '%s\n' "${FAILED_PACKAGES[@]}" | sed 's/^/  - /')

Recommended packages for patching:
${WORKING_PACKAGES[@]}
EOF
    
    echo
    print_success "Report saved to: package_compatibility_report.txt"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi