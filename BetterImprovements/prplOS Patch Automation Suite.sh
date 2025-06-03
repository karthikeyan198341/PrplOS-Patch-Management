#!/bin/bash

#==============================================================================
# prplOS Patch Automation Suite
# Version: 2.0
# Description: Comprehensive patch management system for prplOS with HTML reporting
#==============================================================================

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Default Configuration
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_NAME="prplos-patch-automation-suite"
readonly DEFAULT_WORKSPACE="${PRPLOS_WORKSPACE:-$HOME/prplos-patches}"
readonly DEFAULT_SOURCE_DIR="${PRPLOS_SOURCE:-/opt/prplos/source}"
readonly DEFAULT_PATCH_DIR="${PRPLOS_PATCH_DIR:-$DEFAULT_WORKSPACE/patches}"
readonly DEFAULT_BACKUP_DIR="${PRPLOS_BACKUP_DIR:-$DEFAULT_WORKSPACE/backups}"
readonly DEFAULT_LOG_DIR="${PRPLOS_LOG_DIR:-$DEFAULT_WORKSPACE/logs}"
readonly DEFAULT_RESULTS_DIR="${PRPLOS_RESULTS_DIR:-$DEFAULT_WORKSPACE/results}"
readonly DEFAULT_BUILD_DIR="${PRPLOS_BUILD_DIR:-$DEFAULT_WORKSPACE/build}"
readonly DEFAULT_PATCH_LEVEL="${PRPLOS_PATCH_LEVEL:-1}"
readonly DEFAULT_DRY_RUN="${PRPLOS_DRY_RUN:-false}"
readonly DEFAULT_PARALLEL_JOBS="${PRPLOS_PARALLEL_JOBS:-$(nproc)}"

# Global variables
WORKSPACE="$DEFAULT_WORKSPACE"
SOURCE_DIR="$DEFAULT_SOURCE_DIR"
PATCH_DIR="$DEFAULT_PATCH_DIR"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
LOG_DIR="$DEFAULT_LOG_DIR"
RESULTS_DIR="$DEFAULT_RESULTS_DIR"
BUILD_DIR="$DEFAULT_BUILD_DIR"
PATCH_LEVEL="$DEFAULT_PATCH_LEVEL"
DRY_RUN="$DEFAULT_DRY_RUN"
PARALLEL_JOBS="$DEFAULT_PARALLEL_JOBS"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE=""
HTML_REPORT=""
PATCH_STATS=()
FAILED_PATCHES=()
SUCCESSFUL_PATCHES=()
WARNINGS=()

#==============================================================================
# Utility Functions
#==============================================================================

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        INFO)
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        DEBUG)
            [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
    
    [[ -n "$LOG_FILE" ]] && echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

create_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            log ERROR "Failed to create directory: $dir"
            return 1
        }
        log DEBUG "Created directory: $dir"
    fi
}

validate_patch_format() {
    local patch_file=$1
    
    if [[ ! -f "$patch_file" ]]; then
        log ERROR "Patch file not found: $patch_file"
        return 1
    fi
    
    # Check if it's a valid patch file
    if ! head -n 10 "$patch_file" | grep -qE '^(diff|Index:|---|\\+\\+\\+|@@)'; then
        log ERROR "Invalid patch format: $patch_file"
        return 1
    fi
    
    # Check patch naming convention
    local basename=$(basename "$patch_file")
    if ! [[ "$basename" =~ ^[0-9]{3,4}-.*\.(patch|diff)$ ]]; then
        log WARN "Patch naming doesn't follow convention (NNNN-description.patch): $basename"
        WARNINGS+=("Non-standard patch naming: $basename")
    fi
    
    return 0
}

check_patch_hunks() {
    local patch_file=$1
    local check_output
    
    check_output=$(patch --dry-run -p"$PATCH_LEVEL" < "$patch_file" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        if echo "$check_output" | grep -q "Hunk.*FAILED"; then
            log ERROR "Patch contains failed hunks: $patch_file"
            echo "$check_output" | grep "Hunk.*FAILED" | while read line; do
                log ERROR "  $line"
            done
            return 2
        elif echo "$check_output" | grep -q "can't find file to patch"; then
            log ERROR "Cannot find file to patch: $patch_file"
            return 3
        else
            log ERROR "Patch check failed: $patch_file"
            return 1
        fi
    fi
    
    if echo "$check_output" | grep -q "Hunk.*succeeded.*offset"; then
        log WARN "Patch applies with offset: $patch_file"
        WARNINGS+=("Patch applies with offset: $(basename $patch_file)")
    fi
    
    return 0
}

#==============================================================================
# HTML Report Generation
#==============================================================================

generate_html_header() {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>prplOS Patch Automation Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: #0f0f23;
            color: #e0e0e0;
            line-height: 1.6;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .timestamp {
            opacity: 0.9;
            font-size: 0.9em;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #1a1a2e;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            border: 1px solid #2a2a3e;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.4);
        }
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            margin: 10px 0;
        }
        .metric-label {
            opacity: 0.8;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 1px;
        }
        .success { color: #4ade80; }
        .error { color: #f87171; }
        .warning { color: #fbbf24; }
        .info { color: #60a5fa; }
        .section {
            background: #1a1a2e;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            border: 1px solid #2a2a3e;
        }
        h2 {
            color: #60a5fa;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .icon {
            width: 24px;
            height: 24px;
            fill: currentColor;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #2a2a3e;
        }
        th {
            background: #16213e;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background: #1e1e32;
        }
        .status-badge {
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 500;
            display: inline-block;
        }
        .status-success { background: #065f46; color: #4ade80; }
        .status-failed { background: #7f1d1d; color: #f87171; }
        .status-warning { background: #78350f; color: #fbbf24; }
        .progress-bar {
            width: 100%;
            height: 20px;
            background: #2a2a3e;
            border-radius: 10px;
            overflow: hidden;
            margin-top: 10px;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4ade80 0%, #22c55e 100%);
            transition: width 0.3s ease;
        }
        .log-viewer {
            background: #0a0a0a;
            border: 1px solid #2a2a3e;
            border-radius: 5px;
            padding: 15px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
            max-height: 400px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .log-line { margin: 2px 0; }
        .log-error { color: #f87171; }
        .log-warn { color: #fbbf24; }
        .log-info { color: #4ade80; }
        .footer {
            text-align: center;
            padding: 30px;
            opacity: 0.7;
            font-size: 0.9em;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .processing {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>prplOS Patch Automation Report</h1>
            <div class="timestamp">Generated: TIMESTAMP_PLACEHOLDER</div>
        </div>
EOF
}

generate_html_dashboard() {
    local total_patches=$1
    local successful=$2
    local failed=$3
    local warnings=$4
    local success_rate=$(( total_patches > 0 ? (successful * 100 / total_patches) : 0 ))
    
    cat << EOF
        <div class="dashboard">
            <div class="metric-card">
                <div class="metric-label">Total Patches</div>
                <div class="metric-value info">$total_patches</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Successful</div>
                <div class="metric-value success">$successful</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Failed</div>
                <div class="metric-value error">$failed</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Warnings</div>
                <div class="metric-value warning">$warnings</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Success Rate</div>
                <div class="metric-value">$success_rate%</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $success_rate%"></div>
                </div>
            </div>
        </div>
EOF
}

generate_html_patch_table() {
    cat << 'EOF'
        <div class="section">
            <h2>
                <svg class="icon" viewBox="0 0 24 24"><path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/></svg>
                Patch Details
            </h2>
            <table>
                <thead>
                    <tr>
                        <th>Patch File</th>
                        <th>Status</th>
                        <th>Applied At</th>
                        <th>Details</th>
                    </tr>
                </thead>
                <tbody>
EOF
    
    for stat in "${PATCH_STATS[@]}"; do
        IFS='|' read -r patch_name status timestamp details <<< "$stat"
        local status_class="status-failed"
        [[ "$status" == "SUCCESS" ]] && status_class="status-success"
        [[ "$status" == "WARNING" ]] && status_class="status-warning"
        
        echo "                    <tr>"
        echo "                        <td>$patch_name</td>"
        echo "                        <td><span class=\"status-badge $status_class\">$status</span></td>"
        echo "                        <td>$timestamp</td>"
        echo "                        <td>$details</td>"
        echo "                    </tr>"
    done
    
    echo "                </tbody>"
    echo "            </table>"
    echo "        </div>"
}

generate_html_warnings() {
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        cat << 'EOF'
        <div class="section">
            <h2>
                <svg class="icon" viewBox="0 0 24 24"><path d="M13,14H11V10H13M13,18H11V16H13M1,21H23L12,2L1,21Z"/></svg>
                Warnings
            </h2>
            <ul style="list-style: none; padding-left: 0;">
EOF
        for warning in "${WARNINGS[@]}"; do
            echo "                <li style=\"padding: 8px 0; border-bottom: 1px solid #2a2a3e;\">⚠️ $warning</li>"
        done
        echo "            </ul>"
        echo "        </div>"
    fi
}

generate_html_footer() {
    cat << EOF
        <div class="footer">
            <p>Generated by prplOS Patch Automation Suite v$SCRIPT_VERSION</p>
        </div>
    </div>
</body>
</html>
EOF
}

finalize_html_report() {
    local total_patches=${#PATCH_STATS[@]}
    local successful=${#SUCCESSFUL_PATCHES[@]}
    local failed=${#FAILED_PATCHES[@]}
    local warnings=${#WARNINGS[@]}
    
    {
        generate_html_header | sed "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/"
        generate_html_dashboard "$total_patches" "$successful" "$failed" "$warnings"
        generate_html_patch_table
        generate_html_warnings
        generate_html_footer
    } > "$HTML_REPORT"
    
    log INFO "HTML report generated: $HTML_REPORT"
}

#==============================================================================
# Core Functions
#==============================================================================

setup_environment() {
    log INFO "Setting up patch automation environment..."
    
    # Create necessary directories
    for dir in "$WORKSPACE" "$PATCH_DIR" "$BACKUP_DIR" "$LOG_DIR" "$RESULTS_DIR" "$BUILD_DIR"; do
        create_directory "$dir" || return 1
    done
    
    # Initialize log file
    LOG_FILE="$LOG_DIR/patch_automation_$TIMESTAMP.log"
    HTML_REPORT="$RESULTS_DIR/patch_report_$TIMESTAMP.html"
    
    log INFO "Environment setup completed"
    log INFO "Workspace: $WORKSPACE"
    log INFO "Log file: $LOG_FILE"
    
    return 0
}

apply_patch() {
    local patch_file=$1
    local patch_name=$(basename "$patch_file")
    local backup_name="${patch_name%.patch}_backup_$TIMESTAMP.tar.gz"
    
    log INFO "Applying patch: $patch_name"
    
    # Validate patch format
    if ! validate_patch_format "$patch_file"; then
        FAILED_PATCHES+=("$patch_name")
        PATCH_STATS+=("$patch_name|FAILED|$(date '+%Y-%m-%d %H:%M:%S')|Invalid patch format")
        return 1
    fi
    
    # Check for patch hunks
    check_patch_hunks "$patch_file"
    local hunk_status=$?
    
    if [[ $hunk_status -eq 2 ]]; then
        log ERROR "Patch has failed hunks, attempting to apply with fuzz..."
        local fuzz_result=$(patch --dry-run -p"$PATCH_LEVEL" --fuzz=3 < "$patch_file" 2>&1)
        if [[ $? -eq 0 ]]; then
            log WARN "Patch can be applied with fuzz factor 3"
            WARNINGS+=("Patch applied with fuzz: $patch_name")
        else
            FAILED_PATCHES+=("$patch_name")
            PATCH_STATS+=("$patch_name|FAILED|$(date '+%Y-%m-%d %H:%M:%S')|Failed hunks detected")
            return 1
        fi
    elif [[ $hunk_status -ne 0 ]]; then
        FAILED_PATCHES+=("$patch_name")
        PATCH_STATS+=("$patch_name|FAILED|$(date '+%Y-%m-%d %H:%M:%S')|Patch validation failed")
        return 1
    fi
    
    # Create backup before applying patch
    log INFO "Creating backup: $backup_name"
    cd "$SOURCE_DIR" || return 1
    
    # Get list of files that will be modified
    local files_to_backup=$(patch --dry-run -p"$PATCH_LEVEL" < "$patch_file" 2>&1 | grep "patching file" | awk '{print $3}')
    
    if [[ -n "$files_to_backup" ]]; then
        tar -czf "$BACKUP_DIR/$backup_name" $files_to_backup 2>/dev/null || {
            log WARN "Some files for backup not found, continuing..."
        }
    fi
    
    # Apply the patch
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "DRY RUN: Would apply patch $patch_name"
        patch --dry-run -p"$PATCH_LEVEL" < "$patch_file"
        local apply_status=$?
    else
        patch -p"$PATCH_LEVEL" < "$patch_file"
        local apply_status=$?
    fi
    
    if [[ $apply_status -eq 0 ]]; then
        log INFO "Successfully applied patch: $patch_name"
        SUCCESSFUL_PATCHES+=("$patch_name")
        PATCH_STATS+=("$patch_name|SUCCESS|$(date '+%Y-%m-%d %H:%M:%S')|Applied successfully")
        return 0
    else
        log ERROR "Failed to apply patch: $patch_name"
        FAILED_PATCHES+=("$patch_name")
        PATCH_STATS+=("$patch_name|FAILED|$(date '+%Y-%m-%d %H:%M:%S')|Patch application failed")
        return 1
    fi
}

build_project() {
    log INFO "Starting build process..."
    
    cd "$BUILD_DIR" || return 1
    
    # Configure build
    if [[ -f "$SOURCE_DIR/configure" ]]; then
        log INFO "Running configure..."
        "$SOURCE_DIR/configure" --prefix="$BUILD_DIR/install" || {
            log ERROR "Configure failed"
            return 1
        }
    elif [[ -f "$SOURCE_DIR/CMakeLists.txt" ]]; then
        log INFO "Running cmake..."
        cmake "$SOURCE_DIR" || {
            log ERROR "CMake configuration failed"
            return 1
        }
    fi
    
    # Build
    log INFO "Building with $PARALLEL_JOBS parallel jobs..."
    make -j"$PARALLEL_JOBS" || {
        log ERROR "Build failed"
        return 1
    }
    
    log INFO "Build completed successfully"
    return 0
}

clean_environment() {
    log INFO "Cleaning build environment..."
    
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"/*
        log INFO "Cleaned build directory"
    fi
    
    # Remove any patch reject files
    find "$SOURCE_DIR" -name "*.rej" -o -name "*.orig" | while read reject_file; do
        rm -f "$reject_file"
        log DEBUG "Removed reject file: $reject_file"
    done
    
    log INFO "Environment cleaned"
    return 0
}

monitor_system() {
    log INFO "System monitoring during patch process..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    log INFO "CPU Usage: ${cpu_usage}%"
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
    log INFO "Memory Usage: ${mem_usage}%"
    
    # Disk usage
    local disk_usage=$(df -h "$WORKSPACE" | awk 'NR==2 {print $5}')
    log INFO "Disk Usage for workspace: $disk_usage"
    
    return 0
}

generate_report() {
    log INFO "Generating final report..."
    
    finalize_html_report
    
    # Generate summary log
    local summary_file="$RESULTS_DIR/patch_summary_$TIMESTAMP.txt"
    {
        echo "prplOS Patch Automation Summary"
        echo "==============================="
        echo "Timestamp: $TIMESTAMP"
        echo "Total Patches: ${#PATCH_STATS[@]}"
        echo "Successful: ${#SUCCESSFUL_PATCHES[@]}"
        echo "Failed: ${#FAILED_PATCHES[@]}"
        echo "Warnings: ${#WARNINGS[@]}"
        echo ""
        echo "Failed Patches:"
        printf '%s\n' "${FAILED_PATCHES[@]}"
        echo ""
        echo "Warnings:"
        printf '%s\n' "${WARNINGS[@]}"
    } > "$summary_file"
    
    log INFO "Summary report saved to: $summary_file"
    
    return 0
}

#==============================================================================
# Command Functions
#==============================================================================

cmd_setup() {
    setup_environment || exit 1
    log INFO "Setup completed successfully"
}

cmd_apply() {
    setup_environment || exit 1
    
    # Find all patch files
    local patches=()
    if [[ -n "$1" ]]; then
        # Specific patch provided
        patches=("$1")
    else
        # Apply all patches in patch directory
        while IFS= read -r -d '' patch; do
            patches+=("$patch")
        done < <(find "$PATCH_DIR" -name "*.patch" -o -name "*.diff" | sort | tr '\n' '\0')
    fi
    
    if [[ ${#patches[@]} -eq 0 ]]; then
        log WARN "No patches found in $PATCH_DIR"
        exit 0
    fi
    
    log INFO "Found ${#patches[@]} patches to apply"
    
    # Apply patches
    for patch in "${patches[@]}"; do
        apply_patch "$patch"
        monitor_system
    done
    
    generate_report
}

cmd_build() {
    setup_environment || exit 1
    build_project || exit 1
    generate_report
}

cmd_clean() {
    clean_environment || exit 1
}

cmd_monitor() {
    monitor_system
}

cmd_report() {
    setup_environment || exit 1
    generate_report
}

cmd_full() {
    # Full automation: setup, apply all patches, build, and report
    cmd_setup
    cmd_apply
    cmd_build
    cmd_report
}

#==============================================================================
# Main Script
#==============================================================================

show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    setup       Setup the patch automation environment
    apply       Apply patches (all patches or specific patch)
    build       Build the project after patching
    clean       Clean the build environment
    monitor     Monitor system resources
    report      Generate HTML report
    full        Run full automation (setup, apply, build, report)

Options:
    -w, --workspace DIR      Set workspace directory (default: $DEFAULT_WORKSPACE)
    -s, --source DIR        Set source directory (default: $DEFAULT_SOURCE_DIR)
    -p, --patch-dir DIR     Set patch directory (default: $DEFAULT_PATCH_DIR)
    -b, --backup-dir DIR    Set backup directory (default: $DEFAULT_BACKUP_DIR)
    -l, --log-dir DIR       Set log directory (default: $DEFAULT_LOG_DIR)
    -r, --results-dir DIR   Set results directory (default: $DEFAULT_RESULTS_DIR)
    -L, --patch-level NUM   Set patch level (default: $DEFAULT_PATCH_LEVEL)
    -j, --jobs NUM          Set parallel build jobs (default: $DEFAULT_PARALLEL_JOBS)
    -d, --dry-run          Perform dry run without applying patches
    -v, --verbose          Enable verbose output
    -h, --help             Show this help message

Environment Variables:
    PRPLOS_WORKSPACE        Override default workspace directory
    PRPLOS_SOURCE          Override default source directory
    PRPLOS_PATCH_DIR       Override default patch directory
    PRPLOS_BACKUP_DIR      Override default backup directory
    PRPLOS_LOG_DIR         Override default log directory
    PRPLOS_RESULTS_DIR     Override default results directory
    PRPLOS_BUILD_DIR       Override default build directory
    PRPLOS_PATCH_LEVEL     Override default patch level
    PRPLOS_DRY_RUN         Set to 'true' for dry run mode
    PRPLOS_PARALLEL_JOBS   Override default parallel jobs

Examples:
    # Run full automation with defaults
    $0 full

    # Apply specific patch
    $0 apply /path/to/specific.patch

    # Apply all patches with custom directories
    $0 apply -w /custom/workspace -s /custom/source

    # Dry run to test patches
    $0 apply --dry-run

    # Generate report only
    $0 report

Version: $SCRIPT_VERSION
EOF
}

parse_arguments() {
    local command=""
    
    # Parse command
    if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
        command=$1
        shift
    fi
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--workspace)
                WORKSPACE="$2"
                shift 2
                ;;
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -p|--patch-dir)
                PATCH_DIR="$2"
                shift 2
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -l|--log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            -r|--results-dir)
                RESULTS_DIR="$2"
                shift 2
                ;;
            -L|--patch-level)
                PATCH_LEVEL="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                # Unknown option or additional argument
                break
                ;;
        esac
    done
    
    # Update dependent paths if workspace changed
    if [[ "$WORKSPACE" != "$DEFAULT_WORKSPACE" ]]; then
        [[ "$PATCH_DIR" == "$DEFAULT_PATCH_DIR" ]] && PATCH_DIR="$WORKSPACE/patches"
        [[ "$BACKUP_DIR" == "$DEFAULT_BACKUP_DIR" ]] && BACKUP_DIR="$WORKSPACE/backups"
        [[ "$LOG_DIR" == "$DEFAULT_LOG_DIR" ]] && LOG_DIR="$WORKSPACE/logs"
        [[ "$RESULTS_DIR" == "$DEFAULT_RESULTS_DIR" ]] && RESULTS_DIR="$WORKSPACE/results"
        [[ "$BUILD_DIR" == "$DEFAULT_BUILD_DIR" ]] && BUILD_DIR="$WORKSPACE/build"
    fi
    
    # Execute command or default to full automation
    case ${command:-full} in
        setup)
            cmd_setup
            ;;
        apply)
            cmd_apply "$@"
            ;;
        build)
            cmd_build
            ;;
        clean)
            cmd_clean
            ;;
        monitor)
            cmd_monitor
            ;;
        report)
            cmd_report
            ;;
        full)
            cmd_full
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check if running as root (warn but don't prevent)
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}Warning: Running as root is not recommended${NC}"
fi

# Main execution
parse_arguments "$@"