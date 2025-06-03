#!/bin/bash
# prplos-patch-automation-suite.sh
# Complete automation package for prplOS patch management
# Usage: ./prplos-patch-automation-suite.sh [command] [options]

set -e

# Global configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRPLOS_ROOT="${PRPLOS_ROOT:-$HOME/prplos}"
LOG_DIR="${LOG_DIR:-/var/log/prplos_patch}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/patch_results}"
PATCHES_DIR="${PATCHES_DIR:-$SCRIPT_DIR/patches}"

# Create necessary directories
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$PATCHES_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/automation.log"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check dependencies
check_dependencies() {
    local deps=("git" "quilt" "patch" "bc" "time" "python3")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error_exit "$dep is required but not installed"
        fi
    done
}

# Setup quilt configuration
setup_quilt() {
    if [ ! -f "$HOME/.quiltrc" ]; then
        cat > "$HOME/.quiltrc" << 'EOF'
QUILT_DIFF_ARGS="--no-timestamps --no-index -p ab --color=auto"
QUILT_REFRESH_ARGS="--no-timestamps --no-index -p ab"
QUILT_SERIES_ARGS="--color=auto"
QUILT_PATCH_OPTS="--unified"
QUILT_DIFF_OPTS="-p"
EDITOR="nano"
EOF
        log "Created quilt configuration"
    fi
}

# Generate sample patches
generate_sample_patches() {
    log "Generating sample patches..."
    
    cat > "$PATCHES_DIR/001-network-enhancement.patch" << 'EOF'
--- a/package/network/config/netifd/files/etc/config/network
+++ b/package/network/config/netifd/files/etc/config/network
@@ -10,6 +10,8 @@ config interface 'lan'
 	option proto 'static'
 	option ipaddr '192.168.1.1'
 	option netmask '255.255.255.0'
+	option ip6assign '60'
+	option force_link '1'
 
 config interface 'wan'
 	option ifname 'eth0'
EOF

    cat > "$PATCHES_DIR/002-security-hardening.patch" << 'EOF'
--- a/package/network/config/firewall/files/firewall.config
+++ b/package/network/config/firewall/files/firewall.config
@@ -26,6 +26,12 @@ config zone
 	option masq		1
 	option mtu_fix		1
 
+config rule
+	option name		'Block-Telnet'
+	option src		'wan'
+	option dest_port	'23'
+	option target		'DROP'
+
 config forwarding
 	option src		'lan'
 	option dest		'wan'
EOF

    cat > "$PATCHES_DIR/003-performance-optimization.patch" << 'EOF'
--- a/include/package-defaults.mk
+++ b/include/package-defaults.mk
@@ -50,6 +50,11 @@ else
 endif
 endif
 
+# Enable parallel compilation for faster builds
+ifdef CONFIG_PKG_BUILD_PARALLEL
+  PKG_JOBS?=-j$(shell nproc)
+endif
+
 ifdef CONFIG_USE_MIPS16
   ifeq ($(strip $(PKG_USE_MIPS16)),1)
     TARGET_ASFLAGS_DEFAULT = $(filter-out -mips16 -minterlink-mips16,$(TARGET_CFLAGS))
EOF
    
    log "Generated 3 sample patches in $PATCHES_DIR"
}

# Quilt-based patch application
apply_patch_quilt() {
    local package=$1
    local patch=$2
    
    log "Applying $patch to $package using quilt method"
    
    cd "$PRPLOS_ROOT"
    make package/$package/{clean,prepare} V=s QUILT=1 || error_exit "Failed to prepare $package"
    
    local build_dir=$(find build_dir -name "$package-*" -type d | head -1)
    [ -z "$build_dir" ] && error_exit "Build directory not found for $package"
    
    cd "$build_dir"
    
    # Apply existing patches
    quilt push -a || true
    
    # Import and apply new patch
    quilt import "$patch" || error_exit "Failed to import patch"
    quilt push || error_exit "Failed to apply patch"
    
    # Update patches in buildroot
    cd "$PRPLOS_ROOT"
    make package/$package/update V=s || error_exit "Failed to update patches"
}

# Git-based patch application
apply_patch_git() {
    local package=$1
    local patch=$2
    
    log "Applying $patch to $package using git method"
    
    cd "$PRPLOS_ROOT"
    make package/$package/{clean,prepare} V=s || error_exit "Failed to prepare $package"
    
    local build_dir=$(find build_dir -name "$package-*" -type d | head -1)
    [ -z "$build_dir" ] && error_exit "Build directory not found for $package"
    
    cd "$build_dir"
    
    # Initialize git if needed
    if [ ! -d .git ]; then
        git init
        git add -A
        git commit -m "Initial state"
    fi
    
    # Apply patch
    git apply "$patch" || error_exit "Failed to apply patch with git"
    git add -A
    git commit -m "Applied $(basename $patch)"
    
    # Export to quilt format
    mkdir -p "$PRPLOS_ROOT/package/$package/patches"
    git format-patch -1 --stdout > "$PRPLOS_ROOT/package/$package/patches/$(basename $patch)"
}

# Script-based patch application
apply_patch_script() {
    local package=$1
    local patch=$2
    
    log "Applying $patch to $package using script method"
    
    cd "$PRPLOS_ROOT"
    make package/$package/{clean,prepare} V=s || error_exit "Failed to prepare $package"
    
    local build_dir=$(find build_dir -name "$package-*" -type d | head -1)
    [ -z "$build_dir" ] && error_exit "Build directory not found for $package"
    
    cd "$build_dir"
    
    # Apply patch
    patch -p1 < "$patch" || patch -p1 -F3 < "$patch" || error_exit "Failed to apply patch"
    
    # Copy to package patches directory
    mkdir -p "$PRPLOS_ROOT/package/$package/patches"
    cp "$patch" "$PRPLOS_ROOT/package/$package/patches/$(basename $patch)"
}

# Benchmark function
benchmark_method() {
    local method=$1
    local package=$2
    local patch=$3
    local output_file="$RESULTS_DIR/benchmark_${method}_${package}_$(date +%s).txt"
    
    log "Benchmarking $method method for $package"
    
    # Time the operation
    /usr/bin/time -v -o "$output_file" bash -c "
        case $method in
            quilt)
                $(declare -f apply_patch_quilt)
                apply_patch_quilt '$package' '$patch'
                ;;
            git)
                $(declare -f apply_patch_git)
                apply_patch_git '$package' '$patch'
                ;;
            script)
                $(declare -f apply_patch_script)
                apply_patch_script '$package' '$patch'
                ;;
        esac
    "
    
    # Extract timing information
    local elapsed=$(grep "Elapsed" "$output_file" | awk '{print $8}')
    local cpu=$(grep "Percent of CPU" "$output_file" | awk '{print $6}')
    local max_rss=$(grep "Maximum resident" "$output_file" | awk '{print $6}')
    
    echo "$method,$package,$elapsed,$cpu,$max_rss" >> "$RESULTS_DIR/benchmark_summary.csv"
}

# Compile package
compile_package() {
    local package=$1
    
    log "Compiling $package"
    cd "$PRPLOS_ROOT"
    
    /usr/bin/time -f "Compilation time: %E" \
        make package/$package/compile V=s -j$(nproc) 2>&1 | \
        tee "$LOG_DIR/compile_${package}_$(date +%s).log"
}

# Build complete image
build_image() {
    log "Building complete prplOS image"
    cd "$PRPLOS_ROOT"
    
    /usr/bin/time -f "Image build time: %E" \
        make -j$(nproc) V=s 2>&1 | \
        tee "$LOG_DIR/image_build_$(date +%s).log"
}

# Run complete benchmark
run_benchmark() {
    local packages=("netifd" "firewall" "dnsmasq")
    local methods=("quilt" "git" "script")
    
    # Initialize CSV
    echo "method,package,elapsed_time,cpu_percent,max_memory_kb" > "$RESULTS_DIR/benchmark_summary.csv"
    
    for method in "${methods[@]}"; do
        for package in "${packages[@]}"; do
            # Use first available patch
            local patch=$(ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null | head -1)
            [ -z "$patch" ] && error_exit "No patches found in $PATCHES_DIR"
            
            benchmark_method "$method" "$package" "$patch"
        done
    done
    
    log "Benchmark complete. Results in $RESULTS_DIR/benchmark_summary.csv"
}

# Generate analysis report
generate_report() {
    log "Generating analysis report"
    
    python3 - << 'EOF'
import csv
import json
import os
from datetime import datetime

results_dir = os.environ.get('RESULTS_DIR', '/tmp/patch_results')
csv_file = f"{results_dir}/benchmark_summary.csv"
report_file = f"{results_dir}/analysis_report.json"

if not os.path.exists(csv_file):
    print("No benchmark data found")
    exit(1)

# Read benchmark data
data = []
with open(csv_file, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        data.append(row)

# Analyze results
methods = set(row['method'] for row in data)
packages = set(row['package'] for row in data)

report = {
    'timestamp': datetime.now().isoformat(),
    'summary': {
        'methods_tested': list(methods),
        'packages_tested': list(packages),
        'total_tests': len(data)
    },
    'performance_by_method': {},
    'performance_by_package': {},
    'recommendations': []
}

# Analyze by method
for method in methods:
    method_data = [row for row in data if row['method'] == method]
    times = [float(row['elapsed_time'].split(':')[1]) if ':' in row['elapsed_time'] else float(row['elapsed_time']) for row in method_data]
    
    report['performance_by_method'][method] = {
        'average_time': sum(times) / len(times) if times else 0,
        'min_time': min(times) if times else 0,
        'max_time': max(times) if times else 0,
        'total_tests': len(method_data)
    }

# Determine best method
best_method = min(report['performance_by_method'].items(), 
                  key=lambda x: x[1]['average_time'])[0]
report['recommendations'].append(f"Use {best_method} method for best performance")

# Save report
with open(report_file, 'w') as f:
    json.dump(report, f, indent=2)

print(f"Analysis report saved to {report_file}")
print(json.dumps(report, indent=2))
EOF
}

# Monitor system resources
monitor_resources() {
    local duration=${1:-300}  # Default 5 minutes
    local interval=5
    
    log "Starting resource monitoring for $duration seconds"
    
    (
        echo "timestamp,cpu_usage,memory_usage,load_average"
        end_time=$(($(date +%s) + duration))
        
        while [ $(date +%s) -lt $end_time ]; do
            timestamp=$(date +%s)
            cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
            memory=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
            load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
            
            echo "$timestamp,$cpu,$memory,$load"
            sleep $interval
        done
    ) > "$RESULTS_DIR/resource_monitor.csv" &
    
    echo $! > "$RESULTS_DIR/monitor.pid"
    log "Resource monitor started (PID: $(cat $RESULTS_DIR/monitor.pid))"
}

# Stop resource monitoring
stop_monitor() {
    if [ -f "$RESULTS_DIR/monitor.pid" ]; then
        kill $(cat "$RESULTS_DIR/monitor.pid") 2>/dev/null || true
        rm -f "$RESULTS_DIR/monitor.pid"
        log "Resource monitor stopped"
    fi
}

# Main command handler
case "${1:-help}" in
    setup)
        log "Setting up prplOS patch automation environment"
        check_dependencies
        setup_quilt
        generate_sample_patches
        log "Setup complete"
        ;;
        
    apply)
        [ $# -lt 4 ] && error_exit "Usage: $0 apply <method> <package> <patch>"
        method=$2
        package=$3
        patch=$4
        
        case $method in
            quilt) apply_patch_quilt "$package" "$patch" ;;
            git) apply_patch_git "$package" "$patch" ;;
            script) apply_patch_script "$package" "$patch" ;;
            *) error_exit "Unknown method: $method" ;;
        esac
        ;;
        
    benchmark)
        log "Running patch management benchmark"
        monitor_resources 600  # Monitor for 10 minutes
        run_benchmark
        stop_monitor
        generate_report
        ;;
        
    compile)
        [ $# -lt 2 ] && error_exit "Usage: $0 compile <package>"
        compile_package "$2"
        ;;
        
    build)
        build_image
        ;;
        
    monitor)
        duration=${2:-300}
        monitor_resources "$duration"
        ;;
        
    report)
        generate_report
        ;;
        
    clean)
        log "Cleaning up temporary files"
        rm -rf "$RESULTS_DIR"/*
        rm -f "$LOG_DIR"/*.log
        log "Cleanup complete"
        ;;
        
    help|*)
        cat << EOF
prplOS Patch Management Automation Suite

Usage: $0 <command> [options]

Commands:
    setup                    - Set up environment and generate sample patches
    apply <method> <pkg> <patch> - Apply patch using specified method
                              Methods: quilt, git, script
    benchmark               - Run complete benchmark of all methods
    compile <package>       - Compile specified package
    build                   - Build complete prplOS image
    monitor [duration]      - Monitor system resources
    report                  - Generate analysis report
    clean                   - Clean up temporary files
    help                    - Show this help message

Environment Variables:
    PRPLOS_ROOT    - Path to prplOS source (default: ~/prplos)
    LOG_DIR        - Log directory (default: /var/log/prplos_patch)
    RESULTS_DIR    - Results directory (default: /tmp/patch_results)
    PATCHES_DIR    - Patches directory (default: ./patches)

Examples:
    $0 setup
    $0 apply quilt netifd patches/001-network-enhancement.patch
    $0 benchmark
    $0 report

EOF
        ;;
esac