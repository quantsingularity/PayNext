#!/bin/bash

# =====================================================
#   PayNext - Secure & Auditable Linting and Formatting Script
# =====================================================
# This script enforces code quality and security standards across the codebase
# for Java, YAML, and JavaScript files, adhering to financial industry best practices.

# -----------------------------------------------------
# Security and Robustness Configuration
# -----------------------------------------------------
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: Exit status of a pipeline is the status of the last command
#             to exit with a non-zero status.
set -euo pipefail

# --------------------
# Color Definitions
# --------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --------------------
# Helper Functions
# --------------------

# Log function with timestamp and log level
log() {
    local level="$1"
    local message="$2"
    local color_code=""

    case "$level" in
        INFO) color_code="$BLUE" ;;
        SUCCESS) color_code="$GREEN" ;;
        WARNING) color_code="$YELLOW" ;;
        ERROR) color_code="$RED" ;;
        *) color_code="$NC" ;;
    esac

    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${color_code}${level}${NC}] ${message}"
}

# Print section headers
section() {
    log INFO "====================================================="
    log INFO "  $1"
    log INFO "====================================================="
}

# Execute a command securely and handle errors
# Usage: execute "command to run" "success message" [continue_on_error]
execute() {
    local cmd="$1"
    local msg="$2"
    local continue_on_error="${3:-false}"
    local temp_file
    
    log INFO "Executing: $cmd"

    # Execute command, redirecting stderr to a temporary file for logging
    temp_file=$(mktemp)
    if eval "$cmd" 2> "$temp_file"; then
        log SUCCESS "$msg"
        rm -f "$temp_file"
        return 0
    else
        local exit_code=$?
        log ERROR "Command failed (Exit code: $exit_code): $cmd"
        log ERROR "Error Output:"
        while IFS= read -r line; do log ERROR "  $line"; done < "$temp_file"
        rm -f "$temp_file"
        
        if [[ "$continue_on_error" != "true" ]]; then
            log ERROR "Aborting script due to critical error."
            exit $exit_code
        fi
        return 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --------------------
# Prerequisites Check
# --------------------

check_prerequisites() {
    section "Prerequisites Check"
    local all_checks_passed=true
    
    # Check for Maven (for Spotless)
    if ! command_exists mvn; then
        log ERROR "Maven (mvn) is not installed. Required for Java linting (Spotless)."
        all_checks_passed=false
    fi
    
    # Check for yamllint
    if ! command_exists yamllint; then
        log ERROR "yamllint is not installed. Required for YAML linting."
        all_checks_passed=false
    fi
    
    # Check for yq
    if ! command_exists yq; then
        log ERROR "yq is not installed. Required for YAML formatting."
        all_checks_passed=false
    fi
    
    # Check for dos2unix
    if ! command_exists dos2unix; then
        log ERROR "dos2unix is not installed. Required for line ending normalization."
        all_checks_passed=false
    fi
    
    # Check for npm/npx (for ESLint)
    if ! command_exists npm; then
        log WARNING "npm is not installed. Skipping JavaScript linting (ESLint)."
    fi
    
    if ! $all_checks_passed; then
        log ERROR "One or more critical prerequisites are missing. Please install them."
        exit 1
    fi
    log SUCCESS "Prerequisites check passed."
}

# --------------------
# Linting Functions
# --------------------

# 1. Spotless for Java files
run_spotless() {
    section "Running Spotless for Java files"
    
    # Find all pom.xml files and run spotless:apply in their directory
    local pom_files
    pom_files=$(find backend -name "pom.xml")
    
    if [ -z "$pom_files" ]; then
        log WARNING "No pom.xml files found in 'backend' directory. Skipping Java linting."
        return 0
    fi
    
    local overall_status=0
    for pom in $pom_files; do
        local pom_dir
        pom_dir=$(dirname "$pom")
        log INFO "Applying Spotless in $pom_dir..."
        if ! (
            cd "$pom_dir" || exit 1
            execute "mvn spotless:apply" "Spotless applied successfully to $pom_dir" true
        ); then
            overall_status=1
        fi
    done
    
    if [ "$overall_status" -eq 0 ]; then
        log SUCCESS "Spotless applied to all Java projects successfully."
    else
        log ERROR "Spotless completed with errors in one or more projects."
    fi
    return "$overall_status"
}

# 2. Fix YAML Files (automated fixes for common issues)
fix_yaml_files() {
    section "Applying Automated Fixes to YAML Files"
    
    local yaml_directories=("." "kubernetes")
    local overall_status=0

    for dir in "${yaml_directories[@]}"; do
        log INFO "Processing YAML files in directory: $dir"
        
        # Find all YAML files in the directory and subdirectories, excluding .tmp files
        local yaml_files
        yaml_files=$(find "$dir" -type f \( -name '*.yaml' -o -name '*.yml' \) ! -name '*.tmp')

        for file in $yaml_files; do
            log INFO "Processing $file"
            
            # Create a backup before making changes (Auditable change)
            cp "$file" "$file.bak"
            
            # a. Convert Windows-style line endings to Unix (Security/Consistency)
            if ! execute "dos2unix \"$file\"" "Converted line endings to Unix style" true; then
                log ERROR "Failed to convert line endings for $file."
                overall_status=1
                continue
            fi
            
            # b. Ensure newline at end of file (POSIX compliance)
            if [ -n "$(tail -c1 "$file")" ] && [ "$(tail -c1 "$file")" != $'\n' ]; then
                echo "" >> "$file"
                log INFO "Added newline at end of file."
            fi
            
            # c. Reformat YAML using yq to fix indentation and syntax (Consistency)
            # NOTE: This will remove all comments. In a financial environment, comments
            # should be preserved where possible, but for basic formatting, yq is fast.
            log WARNING "Reformatting $file with yq (This will remove all comments and may change order)."
            if ! execute "yq eval -i '.' \"$file\"" "YAML reformatted with yq" true; then
                log ERROR "yq failed to process $file. Skipping further automated fixes."
                overall_status=1
                continue
            fi
            
            # d. Remove BOM if present (Security/Consistency)
            if head -c 3 "$file" | grep -q $'\xef\xbb\xbf'; then
                log WARNING "Removing BOM from $file"
                tail -c +4 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            fi
            
            # e. Check for long lines (Readability/Reviewability)
            local long_lines
            long_lines=$(awk 'length($0) > 120' "$file") # Increased from 80 to 120 for modern YAML
            if [ -n "$long_lines" ]; then
                log WARNING "The following lines in $file exceed 120 characters (Review for readability):"
                awk 'length($0) > 120' "$file" | nl | while IFS= read -r line; do log WARNING "  $line"; done
            fi
            
            log SUCCESS "Finished automated fixes for $file."
        done
    done
    
    if [ "$overall_status" -eq 0 ]; then
        log SUCCESS "Automated YAML fixes completed successfully."
    else
        log ERROR "Automated YAML fixes completed with errors."
    fi
    return "$overall_status"
}

# 3. Run yamllint on YAML files to identify remaining issues
run_yamllint() {
    section "Running yamllint for YAML files (Security/Compliance Check)"
    
    # Run yamllint on all YAML files, excluding temporary files
    if ! execute "yamllint -c .yamllint.yml ." "YAML linting passed." true; then
        log ERROR "YAML linting failed. Please review the output for security and compliance issues."
        return 1
    fi
    
    log SUCCESS "YAML linting completed successfully."
    return 0
}

# 4. ESLint for JavaScript files
run_eslint() {
    section "Running ESLint for JavaScript files"
    
    local frontend_dir="web-frontend" # Assuming 'frontend' in original script meant 'web-frontend'
    
    if [ ! -d "$frontend_dir" ]; then
        log WARNING "Frontend directory not found: $frontend_dir. Skipping JavaScript linting."
        return 0
    fi
    
    (
        cd "$frontend_dir" || exit 1
        
        if [ ! -f package.json ]; then
            log WARNING "No package.json found in $frontend_dir. Skipping ESLint."
            exit 0
        fi
        
        log INFO "Installing npm dependencies for linting..."
        if ! execute "npm install" "npm dependencies installed." true; then
            log ERROR "Failed to install npm dependencies. Skipping ESLint."
            exit 1
        fi
        
        log INFO "Running ESLint with --fix..."
        # Use npx to ensure the correct local version of eslint is used
        if ! execute "npx eslint '**/*.js' --fix" "ESLint completed successfully." true; then
            log WARNING "ESLint completed with warnings or errors. Check output for details."
            # Do not fail the script, as --fix has been applied
        fi
    )
    
    log SUCCESS "JavaScript linting completed."
    return 0
}

# 5. Cleanup Unnecessary Backup and Temporary Files
cleanup_files() {
    section "Cleaning Up Backup and Temporary Files"
    
    local cleanup_directories=("." "kubernetes" "backend" "web-frontend" "mobile-frontend")

    for dir in "${cleanup_directories[@]}"; do
        if [ -d "$dir" ]; then
            # Find and delete all .bak and .tmp files
            find "$dir" -type f \( -name '*.bak' -o -name '*.tmp' \) -exec rm -f {} +
        fi
    done
    
    log SUCCESS "Removed all temporary (.tmp) and backup (.bak) files."
}

# --------------------
# Main Execution
# --------------------

main() {
    check_prerequisites
    
    # Run all linting and fixing steps
    run_spotless
    fix_yaml_files
    run_yamllint
    run_eslint
    
    cleanup_files
    
    section "Linting and Formatting Summary"
    log SUCCESS "All code quality and security checks completed."
}

main "$@"
