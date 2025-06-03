#!/bin/bash
# fix-prplos-environment.sh
# Fixes permission issues and Python environment for prplOS development

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

# Fix 1: Handle Python virtual environment for externally-managed error
fix_python_environment() {
    print_info "Fixing Python environment issues..."
    
    # Option 1: Create and use a virtual environment (Recommended)
    if command -v python3 &> /dev/null; then
        print_info "Creating Python virtual environment..."
        
        # Create venv in user's home directory
        VENV_DIR="$HOME/prplos-venv"
        
        if [ ! -d "$VENV_DIR" ]; then
            python3 -m venv "$VENV_DIR"
            print_success "Virtual environment created at $VENV_DIR"
        else
            print_info "Virtual environment already exists at $VENV_DIR"
        fi
        
        # Activate virtual environment
        source "$VENV_DIR/bin/activate"
        
        # Upgrade pip in virtual environment
        pip install --upgrade pip
        
        # Install required packages in virtual environment
        print_info "Installing Python packages in virtual environment..."
        pip install matplotlib pandas numpy seaborn psutil requests pyyaml jinja2 pygments tabulate
        
        # Create activation script
        cat > "$HOME/activate-prplos-env.sh" << 'EOF'
#!/bin/bash
# Activate prplOS Python environment
source "$HOME/prplos-venv/bin/activate"
echo "prplOS Python environment activated"
echo "To deactivate, run: deactivate"
EOF
        chmod +x "$HOME/activate-prplos-env.sh"
        
        print_success "Python virtual environment setup complete"
        print_info "To use Python packages, run: source ~/activate-prplos-env.sh"
        
        # Add to bashrc for automatic activation
        if ! grep -q "prplos-venv" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Auto-activate prplOS Python environment" >> ~/.bashrc
            echo "[ -f ~/activate-prplos-env.sh ] && source ~/activate-prplos-env.sh" >> ~/.bashrc
        fi
    fi
    
    # Option 2: Use pipx for isolated environments (if available)
    if command -v pipx &> /dev/null; then
        print_info "pipx is available, you can also use it for isolated installations"
    else
        print_info "Consider installing pipx: sudo apt install pipx"
    fi
}

# Fix 2: Setup proper directory permissions
fix_directory_permissions() {
    print_info "Setting up directories with proper permissions..."
    
    # Create user-writable directories
    WORKSPACE="$HOME/prplos-workspace"
    
    # Create main directories in user's home
    mkdir -p "$WORKSPACE"/{scripts,patches,logs,builds,results}
    
    # Set proper ownership
    chown -R $USER:$USER "$WORKSPACE"
    
    # Create system directories with proper permissions (if needed)
    if [ ! -d "/var/log/prplos_patch" ]; then
        if sudo mkdir -p /var/log/prplos_patch 2>/dev/null; then
            sudo chown $USER:$USER /var/log/prplos_patch
            sudo chmod 755 /var/log/prplos_patch
            print_success "Created /var/log/prplos_patch with user permissions"
        else
            print_warning "Cannot create /var/log/prplos_patch, will use $WORKSPACE/logs instead"
        fi
    fi
    
    # Update environment variables to use user directories
    cat > "$WORKSPACE/prplos-env.sh" << EOF
#!/bin/bash
# prplOS environment variables

# Use user-writable directories
export PRPLOS_ROOT="$WORKSPACE/prplos"
export LOG_DIR="$WORKSPACE/logs"
export RESULTS_DIR="$WORKSPACE/results"
export PATCHES_DIR="$WORKSPACE/patches"
export PATH="$WORKSPACE/scripts:\$PATH"

# Python virtual environment
[ -f ~/activate-prplos-env.sh ] && source ~/activate-prplos-env.sh

echo "prplOS environment loaded"
EOF
    
    chmod +x "$WORKSPACE/prplos-env.sh"
    
    # Add to bashrc
    if ! grep -q "prplos-env.sh" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Load prplOS environment" >> ~/.bashrc
        echo "[ -f $WORKSPACE/prplos-env.sh ] && source $WORKSPACE/prplos-env.sh" >> ~/.bashrc
    fi
    
    print_success "Directory permissions fixed"
}

# Fix 3: Update the automation suite to use user directories
update_automation_scripts() {
    print_info "Updating automation scripts to use user directories..."
    
    WORKSPACE="$HOME/prplos-workspace"
    
    # Create a wrapper script that ensures proper environment
    cat > "$WORKSPACE/scripts/run-prplos-automation.sh" << 'EOF'
#!/bin/bash
# Wrapper script for prplOS automation with proper environment

# Set user-writable directories
export PRPLOS_ROOT="${PRPLOS_ROOT:-$HOME/prplos-workspace/prplos}"
export LOG_DIR="${LOG_DIR:-$HOME/prplos-workspace/logs}"
export RESULTS_DIR="${RESULTS_DIR:-$HOME/prplos-workspace/results}"
export PATCHES_DIR="${PATCHES_DIR:-$HOME/prplos-workspace/patches}"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$PATCHES_DIR"

# Activate Python virtual environment if available
if [ -f "$HOME/prplos-venv/bin/activate" ]; then
    source "$HOME/prplos-venv/bin/activate"
fi

# Run the actual automation script
if [ -f "$HOME/prplos-workspace/scripts/prplos-patch-automation-suite.sh" ]; then
    exec "$HOME/prplos-workspace/scripts/prplos-patch-automation-suite.sh" "$@"
else
    echo "Error: prplos-patch-automation-suite.sh not found in $HOME/prplos-workspace/scripts/"
    echo "Please copy the script to that location first."
    exit 1
fi
EOF
    
    chmod +x "$WORKSPACE/scripts/run-prplos-automation.sh"
    
    # Create a fixed monitoring dashboard launcher
    cat > "$WORKSPACE/scripts/run-monitoring-dashboard.py" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import subprocess

# Ensure we're using the virtual environment
venv_python = os.path.expanduser("~/prplos-venv/bin/python3")
if os.path.exists(venv_python) and sys.executable != venv_python:
    # Re-run with virtual environment Python
    subprocess.run([venv_python] + sys.argv)
    sys.exit()

# Set proper directories
os.environ['RESULTS_DIR'] = os.path.expanduser("~/prplos-workspace/results")
os.environ['LOG_DIR'] = os.path.expanduser("~/prplos-workspace/logs")

# Import and run the dashboard
dashboard_path = os.path.expanduser("~/prplos-workspace/scripts/prplos-monitoring-dashboard.py")
if os.path.exists(dashboard_path):
    exec(open(dashboard_path).read())
else:
    print(f"Error: Dashboard script not found at {dashboard_path}")
    print("Please copy prplos-monitoring-dashboard.py to ~/prplos-workspace/scripts/")
EOF
    
    chmod +x "$WORKSPACE/scripts/run-monitoring-dashboard.py"
    
    print_success "Script wrappers created"
}

# Fix 4: Install Python packages using system package manager as fallback
install_system_python_packages() {
    print_info "Attempting to install Python packages via system package manager..."
    
    if command -v apt-get &> /dev/null; then
        # For Ubuntu/Debian
        local system_packages=(
            python3-matplotlib
            python3-pandas
            python3-numpy
            python3-seaborn
            python3-psutil
            python3-requests
            python3-yaml
            python3-jinja2
            python3-pygments
            python3-tabulate
        )
        
        print_info "Installing system Python packages..."
        for pkg in "${system_packages[@]}"; do
            if apt-cache show "$pkg" &>/dev/null 2>&1; then
                sudo apt-get install -y "$pkg" || print_warning "Failed to install $pkg"
            fi
        done
    fi
}

# Main fix process
main() {
    print_info "=== prplOS Environment Fix Script ==="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        print_error "Please do not run this script as root"
        exit 1
    fi
    
    # Fix Python environment
    fix_python_environment
    
    # Fix directory permissions
    fix_directory_permissions
    
    # Update scripts
    update_automation_scripts
    
    # Try system packages as fallback
    read -p "Do you want to install Python packages via apt? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_system_python_packages
    fi
    
    print_success "=== Environment fixes applied ==="
    print_info "Next steps:"
    print_info "1. Restart your terminal or run: source ~/.bashrc"
    print_info "2. Copy your scripts to: ~/prplos-workspace/scripts/"
    print_info "3. Use the wrapper scripts:"
    print_info "   - ~/prplos-workspace/scripts/run-prplos-automation.sh"
    print_info "   - ~/prplos-workspace/scripts/run-monitoring-dashboard.py"
    print_info ""
    print_info "Example usage:"
    print_info "   cd ~/prplos-workspace"
    print_info "   ./scripts/run-prplos-automation.sh setup"
    print_info "   ./scripts/run-prplos-automation.sh benchmark"
}

# Run main
main "$@"