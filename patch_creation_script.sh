#!/bin/bash

# Automated Patch Creation Script for Development
# Usage: ./create_patch.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository. Please run this script from within a git repository."
        exit 1
    fi
}

# Function to get current branch
get_current_branch() {
    git branch --show-current
}

# Function to check for uncommitted changes
check_uncommitted_changes() {
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes."
        echo "Uncommitted files:"
        git status --porcelain
        echo
        read -p "Do you want to commit these changes first? (y/n): " commit_changes
        if [[ $commit_changes =~ ^[Yy]$ ]]; then
            commit_current_changes
        else
            read -p "Continue without committing? (y/n): " continue_anyway
            if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
                print_error "Aborted by user."
                exit 1
            fi
        fi
    fi
}

# Function to commit current changes
commit_current_changes() {
    print_status "Adding all changes..."
    git add .
    
    echo "Enter commit message:"
    read -r commit_message
    
    if [[ -z "$commit_message" ]]; then
        print_error "Commit message cannot be empty."
        exit 1
    fi
    
    git commit -m "$commit_message"
    print_status "Changes committed successfully."
}

# Function to select patch creation method
select_patch_method() {
    echo
    print_header "Select Patch Creation Method"
    echo "1) Create patch from specific commits"
    echo "2) Create patch from branch comparison"
    echo "3) Create patch from last N commits"
    echo "4) Create patch from uncommitted changes"
    echo
    read -p "Choose method (1-4): " method
    
    case $method in
        1) create_patch_from_commits ;;
        2) create_patch_from_branch ;;
        3) create_patch_from_last_commits ;;
        4) create_patch_from_uncommitted ;;
        *) print_error "Invalid selection. Exiting."; exit 1 ;;
    esac
}

# Function to create patch from specific commits
create_patch_from_commits() {
    print_header "Create Patch from Specific Commits"
    
    echo "Recent commits:"
    git log --oneline -10
    echo
    
    read -p "Enter starting commit hash: " start_commit
    read -p "Enter ending commit hash (or press Enter for HEAD): " end_commit
    
    if [[ -z "$end_commit" ]]; then
        end_commit="HEAD"
    fi
    
    patch_name="patch-${start_commit:0:7}-to-${end_commit:0:7}.patch"
    
    print_status "Creating patch from $start_commit to $end_commit..."
    git format-patch "$start_commit..$end_commit" --stdout > "$patch_name"
    
    print_status "Patch created: $patch_name"
}

# Function to create patch from branch comparison
create_patch_from_branch() {
    print_header "Create Patch from Branch Comparison"
    
    current_branch=$(get_current_branch)
    
    echo "Available branches:"
    git branch -a
    echo
    
    read -p "Enter base branch (default: main): " base_branch
    if [[ -z "$base_branch" ]]; then
        base_branch="main"
    fi
    
    read -p "Enter feature branch (default: $current_branch): " feature_branch
    if [[ -z "$feature_branch" ]]; then
        feature_branch="$current_branch"
    fi
    
    patch_name="patch-${feature_branch}-vs-${base_branch}.patch"
    
    print_status "Creating patch comparing $feature_branch with $base_branch..."
    git format-patch "$base_branch..$feature_branch" --stdout > "$patch_name"
    
    print_status "Patch created: $patch_name"
}

# Function to create patch from last N commits
create_patch_from_last_commits() {
    print_header "Create Patch from Last N Commits"
    
    echo "Recent commits:"
    git log --oneline -10
    echo
    
    read -p "Enter number of commits to include: " num_commits
    
    if ! [[ "$num_commits" =~ ^[0-9]+$ ]]; then
        print_error "Please enter a valid number."
        exit 1
    fi
    
    patch_name="patch-last-${num_commits}-commits.patch"
    
    print_status "Creating patch from last $num_commits commits..."
    git format-patch -"$num_commits" --stdout > "$patch_name"
    
    print_status "Patch created: $patch_name"
}

# Function to create patch from uncommitted changes
create_patch_from_uncommitted() {
    print_header "Create Patch from Uncommitted Changes"
    
    if git diff-index --quiet HEAD --; then
        print_error "No uncommitted changes found."
        exit 1
    fi
    
    echo "Uncommitted changes:"
    git status --porcelain
    echo
    
    patch_name="patch-uncommitted-$(date +%Y%m%d-%H%M%S).patch"
    
    print_status "Creating patch from uncommitted changes..."
    git diff HEAD > "$patch_name"
    
    print_status "Patch created: $patch_name"
}

# Function to add metadata to patch
add_patch_metadata() {
    if [[ -f "$patch_name" ]]; then
        echo
        read -p "Add patch description? (y/n): " add_desc
        if [[ $add_desc =~ ^[Yy]$ ]]; then
            echo "Enter patch description:"
            read -r patch_description
            
            # Create temporary file with metadata
            temp_file=$(mktemp)
            echo "# Patch Description: $patch_description" > "$temp_file"
            echo "# Created: $(date)" >> "$temp_file"
            echo "# Repository: $(basename $(git rev-parse --show-toplevel))" >> "$temp_file"
            echo "# Branch: $(get_current_branch)" >> "$temp_file"
            echo "" >> "$temp_file"
            cat "$patch_name" >> "$temp_file"
            mv "$temp_file" "$patch_name"
            
            print_status "Metadata added to patch."
        fi
    fi
}

# Function to validate and summarize patch
summarize_patch() {
    if [[ -f "$patch_name" ]]; then
        echo
        print_header "Patch Summary"
        echo "Patch file: $patch_name"
        echo "Size: $(du -h "$patch_name" | cut -f1)"
        echo "Lines: $(wc -l < "$patch_name")"
        
        if command -v diffstat &> /dev/null; then
            echo
            echo "Diffstat:"
            diffstat "$patch_name"
        fi
        
        echo
        read -p "View patch content? (y/n): " view_patch
        if [[ $view_patch =~ ^[Yy]$ ]]; then
            less "$patch_name"
        fi
    fi
}

# Main function
main() {
    print_header "Automated Patch Creation Script"
    
    # Check prerequisites
    check_git_repo
    
    # Show current repository status
    print_status "Repository: $(basename $(git rev-parse --show-toplevel))"
    print_status "Current branch: $(get_current_branch)"
    
    # Check for uncommitted changes
    check_uncommitted_changes
    
    # Select and execute patch creation method
    select_patch_method
    
    # Add metadata if requested
    add_patch_metadata
    
    # Summarize patch
    summarize_patch
    
    echo
    print_status "Patch creation completed successfully!"
    
    # Optional: Open output directory
    read -p "Open directory containing the patch? (y/n): " open_dir
    if [[ $open_dir =~ ^[Yy]$ ]]; then
        if command -v xdg-open &> /dev/null; then
            xdg-open .
        elif command -v open &> /dev/null; then
            open .
        else
            print_status "Patch saved in: $(pwd)/$patch_name"
        fi
    fi
}

# Run main function
main "$@"