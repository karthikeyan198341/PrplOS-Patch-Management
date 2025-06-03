#!/bin/bash
# prplos-universal-installer.sh
# Universal installer for prplOS development prerequisites
# Supports: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch, MSYS2, macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_banner() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         prplOS Development Environment Installer          ║"
    echo "║                    Universal Setup Script                 ║"
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
}

check_prerequisites() {
    local missing_count=0
    
    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Running as root is not recommended. Consider using a regular user with sudo."
    fi
    
    # Check available disk space
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 50 ]; then
        print_warning "Less than 50GB free space. Recommended: 100GB+"
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

install_ubuntu_debian() {
    print_info "Installing packages for Ubuntu/Debian..."
    
    # Update package list
    sudo apt-get update
    
    # Essential packages
    local packages=(
        # Build essentials
        build-essential
        gcc
        g++
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
        
        # Patch management
        quilt
        patch
        diffutils
        patchutils
        
        # Development libraries
        libncurses5-dev
        libncursesw5-dev
        zlib1g-dev
        libssl-dev
        libelf-dev
        liblzma-dev
        libbz2-dev
        libreadline-dev
        libsqlite3-dev
        
        # Python
        python3
        python3-dev
        python3-pip
        python3-setuptools
        python3-distutils
        python3-venv
        python3-wheel
        
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
        libtext-csv-perl
        xsltproc
        libxml2-utils
        bison
        flex
        
        # Optional but recommended
        ccache
        ninja-build
        tmux
        htop
        iotop
        sysstat
        tree
        ncdu
    )
    
    print_info "Installing ${#packages[@]} packages..."
    sudo apt-get install -y "${packages[@]}"
    
    print_success "Ubuntu/Debian packages installed successfully"
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
        sudo $pkg_manager install -y epel-release
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
        iotop
        sysstat
    )
    
    print_info "Installing ${#packages[@]} packages..."
    sudo $pkg_manager install -y "${packages[@]}"
    
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
        iotop
        sysstat
    )
    
    print_info "Installing ${#packages[@]} packages..."
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    
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
        libelf
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
    
    print_info "Installing ${#packages[@]} packages..."
    brew install "${packages[@]}"
    
    # macOS-specific setup
    print_info "Setting up macOS-specific configurations..."
    
    # Add GNU tools to PATH
    echo 'export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >> ~/.bash_profile
    echo 'export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"' >> ~/.bash_profile
    echo 'export PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"' >> ~/.bash_profile
    echo 'export PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"' >> ~/.bash_profile
    
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
    pacman -Syu --noconfirm
    
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
        mingw-w64-ucrt-x86_64-libelf
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
        ncurses-devel
        zlib-devel
        openssl-devel
        
        # Optional
        mingw-w64-ucrt-x86_64-ccache
        tmux
        tree
    )
    
    print_info "Installing ${#packages[@]} packages..."
    pacman -S --needed --noconfirm "${packages[@]}"
    
    # MSYS2-specific configurations
    print_info "Configuring MSYS2 environment..."
    
    # Fix git line endings
    git config --global core.autocrlf false
    git config --global core.eol lf
    
    print_success "MSYS2 packages installed successfully"
}

install_python_packages() {
    print_info "Installing Python packages..."
    
    local pip_cmd="pip3"
    if ! command -v pip3 &> /dev/null; then
        pip_cmd="pip"
    fi
    
    # Upgrade pip first
    $pip_cmd install --upgrade pip
    
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
    
    print_info "Installing ${#python_packages[@]} Python packages..."
    $pip_cmd install --user "${python_packages[@]}"
    
    print_success "Python packages installed successfully"
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
    
    # Check if git user is configured
    if ! git config --get user.name &> /dev/null; then
        print_warning "Git user name not configured"
        read -p "Enter your name for git commits: " git_name
        git config --global user.name "$git_name"
    fi
    
    if ! git config --get user.email &> /dev/null; then
        print_warning "Git email not configured"
        read -p "Enter your email for git commits: " git_email
        git config --global user.email "$git_email"
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
    local commands=(gcc g++ make git quilt patch python3 bc wget curl)
    
    for cmd in "${commands[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>&1 | head -n1)
            print_success "$cmd: OK - $version"
        else
            print_error "$cmd: NOT FOUND"
            ((failed++))
        fi
    done
    
    # Check Python packages
    print_info "Checking Python packages..."
    for pkg in matplotlib pandas numpy seaborn; do
        if python3 -c "import $pkg" 2>/dev/null; then
            print_success "Python $pkg: OK"
        else
            print_error "Python $pkg: NOT INSTALLED"
            ((failed++))
        fi
    done
    
    # Check quilt configuration
    if [ -f ~/.quiltrc ]; then
        print_success "Quilt configuration: OK"
    else
        print_warning "Quilt configuration: NOT FOUND"
    fi
    
    if [ $failed -eq 0 ]; then
        print_success "All checks passed! Environment is ready for prplOS development."
        return 0
    else
        print_error "$failed checks failed. Please review and install missing components."
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
            sudo apt-get install -y wslu
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
    verify_installation
    
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
    print_success "Happy patching!"
}

# Run main function
main "$@"