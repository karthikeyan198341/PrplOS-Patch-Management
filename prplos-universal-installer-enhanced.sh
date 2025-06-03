#!/bin/bash
# prplos-universal-installer.sh - Enhanced Version
# Universal installer for prplOS development prerequisites
# Supports: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch, MSYS2, macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
trap 'error_handler $? $LINENO' ERR

error_handler() {
    print_error "Error occurred in script at line $2 with exit code $1"
    exit $1
}

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         prplOS Development Environment Installer          ║"
    echo "║              Universal Setup Script v2.0                  ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            VER=$VERSION_ID
            PRETTY_NAME=$PRETTY_NAME
            VERSION_CODENAME=${VERSION_CODENAME:-}
        elif [ -f /etc/redhat-release ]; then
            OS="rhel"
            VER=$(rpm -E %{rhel})
        else
            OS="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        VER=$(sw_vers -productVersion)
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="msys2"
        VER=$MSYSTEM
    elif [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
        print_error "Native Windows detected. Please use WSL2 or MSYS2 instead."
        exit 1
    else
        OS="unknown"
    fi
    
    print_info "Detected OS: $OS $VER"
    [ -n "$PRETTY_NAME" ] && print_info "Distribution: $PRETTY_NAME"
    [ -n "$VERSION_CODENAME" ] && print_info "Codename: $VERSION_CODENAME"
}

check_prerequisites() {
    local missing_count=0
    
    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Running as root is not recommended. Consider using a regular user with sudo."
    fi
    
    # Check if sudo is available
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed. Please install sudo first."
        exit 1
    fi
    
    # Check available disk space
    if command -v df &> /dev/null; then
        available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
        if [ "$available_space" -lt 50 ]; then
            print_warning "Less than 50GB free space. Recommended: 100GB+"
        fi
    fi
    
    # Check RAM
    if command -v free &> /dev/null; then
        total_ram=$(free -g | awk '/^Mem:/ {print $2}')
        if [ "$total_ram" -lt 4 ]; then
            print_warning "Less than 4GB RAM detected. Recommended: 8GB+"
        fi
    fi
    
    return $missing_count
}

# Function to check if a package is available
check_package_available() {
    local package=$1
    if apt-cache show "$package" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to install package with fallback
install_package_with_fallback() {
    local primary=$1
    local fallback=$2
    
    if check_package_available "$primary"; then
        echo "$primary"
    elif [ -n "$fallback" ] && check_package_available "$fallback"; then
        print_warning "Package $primary not found, using $fallback instead"
        echo "$fallback"
    else
        print_warning "Neither $primary nor $fallback found, skipping..."
        echo ""
    fi
}

install_ubuntu_debian() {
    print_info "Installing packages for Ubuntu/Debian..."
    
    # Detect Ubuntu version
    local ubuntu_version=""
    if [[ "$OS" == "ubuntu" ]]; then
        ubuntu_version=$(echo "$VER" | cut -d. -f1)
        print_info "Ubuntu version: $ubuntu_version"
    fi
    
    # Update package list
    print_info "Updating package lists..."
    sudo apt-get update || {
        print_error "Failed to update package lists"
        print_info "Trying to fix package issues..."
        sudo apt-get update --fix-missing
    }
    
    # Core packages that should always be installed
    local core_packages=(
        build-essential
        gcc
        g++
        make
        cmake
        automake
        autoconf
        libtool
        pkg-config
        git
        subversion
        quilt
        patch
        diffutils
        patchutils
        gawk
        wget
        curl
        file
        unzip
        rsync
        bc
        time
        gettext
        bison
        flex
        ccache
    )
    
    # Install core packages first
    print_info "Installing core packages..."
    for pkg in "${core_packages[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            sudo apt-get install -y "$pkg" || print_warning "Failed to install $pkg"
        fi
    done
    
    # Handle version-specific packages
    local version_specific_packages=()
    
    # Python packages - handle distutils deprecation
    if [[ "$ubuntu_version" -ge 23 ]] || [[ "$VERSION_CODENAME" == "lunar" ]] || [[ "$VERSION_CODENAME" == "mantic" ]] || [[ "$VERSION_CODENAME" == "noble" ]]; then
        print_info "Ubuntu 23.04+ detected, using python3-setuptools instead of python3-distutils"
        version_specific_packages+=(
            python3
            python3-dev
            python3-pip
            python3-setuptools
            python3-venv
            python3-wheel
            python3-full
        )
    else
        # Older Ubuntu versions
        version_specific_packages+=(
            python3
            python3-dev
            python3-pip
            python3-setuptools
        )
        
        # Only add distutils if available
        if check_package_available "python3-distutils"; then
            version_specific_packages+=(python3-distutils)
        fi
    fi
    
    # Handle ncurses package variations
    local ncurses_pkg=$(install_package_with_fallback "libncurses-dev" "libncurses5-dev")
    [ -n "$ncurses_pkg" ] && version_specific_packages+=("$ncurses_pkg")
    
    local ncursesw_pkg=$(install_package_with_fallback "libncursesw5-dev" "libncurses5-dev")
    [ -n "$ncursesw_pkg" ] && version_specific_packages+=("$ncursesw_pkg")
    
    # Other development libraries
    local dev_packages=(
        zlib1g-dev
        libssl-dev
        libelf-dev
        liblzma-dev
        libbz2-dev
        libreadline-dev
        libsqlite3-dev
        libxml2-utils
        xsltproc
    )
    
    # Add available dev packages
    for pkg in "${dev_packages[@]}"; do
        if check_package_available "$pkg"; then
            version_specific_packages+=("$pkg")
        else
            print_warning "Package $pkg not available, skipping..."
        fi
    done
    
    # Optional but recommended packages
    local optional_packages=(
        git-lfs
        mercurial
        ninja-build
        tmux
        htop
        tree
        ncdu
    )
    
    # Install version-specific packages
    if [ ${#version_specific_packages[@]} -gt 0 ]; then
        print_info "Installing version-specific packages..."
        sudo apt-get install -y "${version_specific_packages[@]}" || {
            print_warning "Some packages failed to install, continuing..."
        }
    fi
    
    # Try to install optional packages (don't fail if they're not available)
    print_info "Installing optional packages..."
    for pkg in "${optional_packages[@]}"; do
        if check_package_available "$pkg"; then
            sudo apt-get install -y "$pkg" || true
        fi
    done
    
    # Install pip if not already installed
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        print_info "Installing pip using get-pip.py..."
        wget -q https://bootstrap.pypa.io/get-pip.py
        python3 get-pip.py --user || {
            print_warning "Failed to install pip via get-pip.py"
            # Try alternative method
            if check_package_available "python3-pip"; then
                sudo apt-get install -y python3-pip
            fi
        }
        rm -f get-pip.py
    fi
    
    print_success "Ubuntu/Debian packages installation completed"
}

install_fedora_rhel() {
    print_info "Installing packages for Fedora/RHEL/CentOS..."
    
    # Use dnf if available, otherwise yum
    local pkg_manager="dnf"
    if ! command -v dnf &> /dev/null; then
        pkg_manager="yum"
    fi
    
    # Enable EPEL on RHEL/CentOS
    if [[ "$OS" == "rhel" ]] || [[ "$OS" == "centos" ]]; then
        sudo $pkg_manager install -y epel-release || true
    fi
    
    local packages=(
        # Development tools
        "@development-tools"
        gcc
        gcc-c++
        make
        cmake
        automake
        autoconf
        libtool
        
        # Version control
        git
        git-lfs
        subversion
        mercurial
        
        # Patch tools
        quilt
        patch
        diffutils
        patchutils
        
        # Libraries
        ncurses-devel
        zlib-devel
        openssl-devel
        elfutils-libelf-devel
        xz-devel
        bzip2-devel
        readline-devel
        sqlite-devel
        
        # Python
        python3
        python3-devel
        python3-pip
        python3-setuptools
        
        # Tools
        gawk
        wget
        curl
        file
        unzip
        rsync
        bc
        time
        gettext
        libxml2
        libxslt
        bison
        flex
        
        # Optional
        ccache
        ninja-build
        tmux
        htop
        tree
    )
    
    print_info "Installing packages..."
    for pkg in "${packages[@]}"; do
        sudo $pkg_manager install -y "$pkg" || print_warning "Failed to install $pkg"
    done
    
    print_success "Fedora/RHEL packages installed successfully"
}

install_arch() {
    print_info "Installing packages for Arch Linux..."
    
    # Update package database
    sudo pacman -Sy
    
    local packages=(
        # Base development
        base-devel
        gcc
        make
        cmake
        automake
        autoconf
        libtool
        pkg-config
        
        # Version control
        git
        git-lfs
        subversion
        mercurial
        
        # Patch tools
        quilt
        patch
        diffutils
        
        # Libraries
        ncurses
        zlib
        openssl
        libelf
        xz
        bzip2
        readline
        sqlite
        
        # Python
        python
        python-pip
        python-setuptools
        
        # Tools
        gawk
        wget
        curl
        file
        unzip
        rsync
        bc
        time
        gettext
        libxml2
        libxslt
        bison
        flex
        
        # Optional
        ccache
        ninja
        tmux
        htop
        tree
    )
    
    print_info "Installing packages..."
    sudo pacman -S --needed --noconfirm "${packages[@]}" || {
        print_warning "Some packages failed to install, continuing..."
    }
    
    print_success "Arch Linux packages installed successfully"
}

install_macos() {
    print_info "Installing packages for macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    local packages=(
        # Development tools
        gcc
        make
        cmake
        automake
        autoconf
        libtool
        pkg-config
        
        # Version control
        git
        git-lfs
        subversion
        mercurial
        
        # Patch tools
        quilt
        gpatch
        diffutils
        
        # Libraries
        ncurses
        zlib
        openssl
        xz
        bzip2
        readline
        sqlite
        
        # Python
        python@3.11
        
        # Tools
        gawk
        wget
        curl
        coreutils
        gnu-sed
        gnu-tar
        gnu-getopt
        findutils
        rsync
        bc
        gettext
        libxml2
        libxslt
        bison
        flex
        
        # Optional
        ccache
        ninja
        tmux
        htop
    )
    
    print_info "Installing packages..."
    for pkg in "${packages[@]}"; do
        brew install "$pkg" || print_warning "Failed to install $pkg"
    done
    
    # macOS-specific setup
    print_info "Setting up macOS-specific configurations..."
    
    # Add GNU tools to PATH
    cat >> ~/.bash_profile << 'EOF'

# GNU tools for prplOS development
export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
EOF
    
    print_success "macOS packages installed successfully"
    print_warning "Please restart your terminal or run: source ~/.bash_profile"
}

install_msys2() {
    print_info "Installing packages for MSYS2..."
    
    # Check if in correct environment
    if [[ "$MSYSTEM" != "UCRT64" ]]; then
        print_error "Please run this script in MSYS2 UCRT64 terminal!"
        print_info "Close this terminal and open 'MSYS2 UCRT64' from Start Menu"
        exit 1
    fi
    
    # Update MSYS2
    print_info "Updating MSYS2..."
    pacman -Syu --noconfirm || {
        print_warning "Initial update requires restart. Please restart MSYS2 and run this script again."
        exit 0
    }
    
    local packages=(
        # Base development
        base-devel
        mingw-w64-ucrt-x86_64-toolchain
        mingw-w64-ucrt-x86_64-cmake
        mingw-w64-ucrt-x86_64-ninja
        mingw-w64-ucrt-x86_64-pkg-config
        
        # Version control
        git
        subversion
        mercurial
        
        # Patch tools
        quilt
        patch
        diffutils
        patchutils
        dos2unix
        
        # Python
        mingw-w64-ucrt-x86_64-python
        mingw-w64-ucrt-x86_64-python-pip
        
        # Libraries
        mingw-w64-ucrt-x86_64-ncurses
        mingw-w64-ucrt-x86_64-zlib
        mingw-w64-ucrt-x86_64-openssl
        mingw-w64-ucrt-x86_64-xz
        mingw-w64-ucrt-x86_64-bzip2
        mingw-w64-ucrt-x86_64-readline
        mingw-w64-ucrt-x86_64-sqlite3
        
        # Tools
        autoconf
        automake
        libtool
        make
        wget
        curl
        rsync
        bc
        time
        unzip
        
        # Optional
        mingw-w64-ucrt-x86_64-ccache
        tmux
        tree
    )
    
    print_info "Installing packages..."
    pacman -S --needed --noconfirm "${packages[@]}" || {
        print_warning "Some packages failed to install, continuing..."
    }
    
    # MSYS2-specific configurations
    print_info "Configuring MSYS2 environment..."
    
    # Fix git line endings
    git config --global core.autocrlf false
    git config --global core.eol lf
    
    print_success "MSYS2 packages installed successfully"
}

install_python_packages() {
    print_info "Installing Python packages..."
    
    # Find the correct pip command
    local pip_cmd=""
    if command -v pip3 &> /dev/null; then
        pip_cmd="pip3"
    elif command -v pip &> /dev/null; then
        pip_cmd="pip"
    elif command -v python3 &> /dev/null; then
        pip_cmd="python3 -m pip"
    elif command -v python &> /dev/null; then
        pip_cmd="python -m pip"
    else
        print_error "No pip installation found!"
        print_info "Attempting to install pip..."
        
        # Try to install pip
        if command -v python3 &> /dev/null; then
            curl https://bootstrap.pypa.io/get-pip.py | python3
            pip_cmd="python3 -m pip"
        else
            print_error "Cannot install pip. Please install Python and pip manually."
            return 1
        fi
    fi
    
    print_info "Using pip command: $pip_cmd"
    
    # Upgrade pip first
    $pip_cmd install --upgrade pip || print_warning "Failed to upgrade pip"
    
    local python_packages=(
        matplotlib
        pandas
        numpy
        seaborn
        psutil
        requests
        pyyaml
        jinja2
        pygments
        tabulate
    )
    
    print_info "Installing Python packages..."
    for pkg in "${python_packages[@]}"; do
        print_info "Installing $pkg..."
        $pip_cmd install --user "$pkg" || print_warning "Failed to install $pkg"
    done
    
    print_success "Python packages installation completed"
}

setup_quilt() {
    print_info "Setting up quilt configuration..."
    
    # Create quilt configuration
    cat > ~/.quiltrc << 'EOF'
QUILT_DIFF_ARGS="--no-timestamps --no-index -p ab --color=auto"
QUILT_REFRESH_ARGS="--no-timestamps --no-index -p ab"
QUILT_SERIES_ARGS="--color=auto"
QUILT_PATCH_OPTS="--unified"
QUILT_DIFF_OPTS="-p"
EDITOR="${EDITOR:-nano}"
QUILT_PATCHES_PREFIX=yes
QUILT_NO_DIFF_INDEX=yes
QUILT_NO_DIFF_TIMESTAMPS=yes
EOF
    
    print_success "Quilt configuration created at ~/.quiltrc"
}

setup_git() {
    print_info "Setting up git configuration..."
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_warning "Git is not installed, skipping git setup"
        return
    fi
    
    # Check if git user is configured
    if ! git config --get user.name &> /dev/null; then
        print_warning "Git user name not configured"
        read -p "Enter your name for git commits (or press Enter to skip): " git_name
        if [ -n "$git_name" ]; then
            git config --global user.name "$git_name"
        fi
    fi
    
    if ! git config --get user.email &> /dev/null; then
        print_warning "Git email not configured"
        read -p "Enter your email for git commits (or press Enter to skip): " git_email
        if [ -n "$git_email" ]; then
            git config --global user.email "$git_email"
        fi
    fi
    
    # Set useful git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    
    print_success "Git configuration completed"
}

create_workspace() {
    print_info "Creating prplOS workspace..."
    
    local workspace="$HOME/prplos-workspace"
    mkdir -p "$workspace"
    
    # Create directory structure
    mkdir -p "$workspace"/{patches,scripts,builds,logs}
    
    # Create a README
    cat > "$workspace/README.md" << 'EOF'
# prplOS Development Workspace

This workspace is configured for prplOS development.

## Directory Structure
- `patches/` - Store your patch files here
- `scripts/` - Development scripts
- `builds/` - Build outputs
- `logs/` - Build and test logs
- `prplos/` - prplOS source (clone here)

## Quick Start
1. Clone prplOS: `git clone https://gitlab.com/prpl-foundation/prplos/prplos.git`
2. Copy patch management scripts to `scripts/`
3. Run: `./scripts/prplos-patch-automation-suite.sh setup`

## Environment Variables
Add to your shell profile:
```bash
export PRPLOS_ROOT="$HOME/prplos-workspace/prplos"
export PATH="$HOME/prplos-workspace/scripts:$PATH"
```
EOF
    
    print_success "Workspace created at: $workspace"
    print_info "Add this to your shell profile:"
    echo "export PRPLOS_ROOT=\"$workspace/prplos\""
    echo "export PATH=\"$workspace/scripts:\$PATH\""
}

verify_installation() {
    print_info "Verifying installation..."
    
    local failed=0
    local warnings=0
    
    # Essential commands
    local essential_commands=(gcc make git python3)
    local optional_commands=(g++ quilt patch bc wget curl ccache)
    
    print_info "Checking essential tools..."
    for cmd in "${essential_commands[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>&1 | head -n1 || echo "version unknown")
            print_success "$cmd: OK - $version"
        else
            print_error "$cmd: NOT FOUND (REQUIRED)"
            ((failed++))
        fi
    done
    
    print_info "Checking optional tools..."
    for cmd in "${optional_commands[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>&1 | head -n1 || echo "version unknown")
            print_success "$cmd: OK"
        else
            print_warning "$cmd: NOT FOUND (optional)"
            ((warnings++))
        fi
    done
    
    # Check Python packages
    print_info "Checking Python packages..."
    local python_cmd="python3"
    if ! command -v python3 &> /dev/null; then
        python_cmd="python"
    fi
    
    for pkg in matplotlib pandas numpy seaborn; do
        if $python_cmd -c "import $pkg" 2>/dev/null; then
            print_success "Python $pkg: OK"
        else
            print_warning "Python $pkg: NOT INSTALLED (optional)"
            ((warnings++))
        fi
    done
    
    # Check quilt configuration
    if [ -f ~/.quiltrc ]; then
        print_success "Quilt configuration: OK"
    else
        print_warning "Quilt configuration: NOT FOUND"
        ((warnings++))
    fi
    
    # Summary
    echo
    if [ $failed -eq 0 ]; then
        if [ $warnings -eq 0 ]; then
            print_success "All checks passed! Environment is ready for prplOS development."
        else
            print_success "Essential tools are installed. $warnings optional components are missing."
            print_info "You can proceed with prplOS development."
        fi
        return 0
    else
        print_error "$failed essential tools are missing. Please install them before proceeding."
        return 1
    fi
}

install_wsl2_check() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        print_info "WSL2 environment detected"
        print_info "Applying WSL2-specific optimizations..."
        
        # WSL2-specific configurations
        # Fix clock skew issues
        if command -v hwclock &> /dev/null; then
            sudo hwclock -s 2>/dev/null || true
        fi
        
        # Add WSL2 utilities if available
        if ! command -v wslu &> /dev/null && command -v apt-get &> /dev/null; then
            if check_package_available "wslu"; then
                sudo apt-get install -y wslu || true
            fi
        fi
        
        print_success "WSL2 optimizations applied"
    fi
}

main() {
    print_banner
    
    # Detect OS
    detect_os
    
    # Check prerequisites
    check_prerequisites
    
    # Install packages based on OS
    case $OS in
        ubuntu|debian)
            install_ubuntu_debian
            ;;
        fedora|rhel|centos)
            install_fedora_rhel
            ;;
        arch|manjaro)
            install_arch
            ;;
        macos)
            install_macos
            ;;
        msys2)
            install_msys2
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Please install packages manually"
            exit 1
            ;;
    esac
    
    # Common setup steps
    install_python_packages
    setup_quilt
    setup_git
    
    # Check for WSL2
    install_wsl2_check
    
    # Create workspace
    create_workspace
    
    # Verify installation
    echo
    verify_installation || true
    
    # Final instructions
    echo
    print_info "==== Installation Complete ===="
    print_info "Next steps:"
    print_info "1. Restart your terminal or source your shell profile"
    print_info "2. Navigate to: ~/prplos-workspace"
    print_info "3. Clone prplOS: git clone https://gitlab.com/prpl-foundation/prplos/prplos.git"
    print_info "4. Copy the patch management scripts to ~/prplos-workspace/scripts/"
    print_info "5. Run: ./scripts/prplos-patch-automation-suite.sh setup"
    echo
    
    # Show any specific notes based on what was installed
    if [ $failed -gt 0 ] 2>/dev/null; then
        print_warning "Some essential components are missing. Please install them manually."
    else
        print_success "Your system is ready for prplOS development!"
    fi
    
    # OS-specific notes
    case $OS in
        ubuntu|debian)
            if [[ "$ubuntu_version" -ge 23 ]] 2>/dev/null; then
                print_info "Note: Ubuntu 23.04+ uses python3-setuptools instead of python3-distutils"
            fi
            ;;
        msys2)
            print_info "Note: Remember to always use MSYS2 UCRT64 terminal for development"
            ;;
        macos)
            print_info "Note: Remember to use GNU versions of tools (they were added to PATH)"
            ;;
    esac
}

# Run main function
main "$@"