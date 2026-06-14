#!/bin/bash

# =====================================================
#   PayNext - Secure Maven Build and Compose Deployment
# =====================================================
# This script automates the secure build of Maven and Node projects
# and deploys them using Docker Compose, with enhanced logging and
# robustness for a financial environment.

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
        cat "$temp_file" | while IFS= read -r line; do log ERROR "  $line"; done
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
    
    if ! command_exists mvn; then
        log ERROR "Maven (mvn) could not be found. Required for backend build."
        all_checks_passed=false
    fi
    
    if ! command_exists npm; then
        log ERROR "npm could not be found. Required for frontend build."
        all_checks_passed=false
    fi
    
    if ! command_exists docker-compose; then
        log ERROR "Docker Compose could not be found. Required for deployment."
        all_checks_passed=false
    fi
    
    if [ ! -d "backend" ]; then
        log ERROR "Backend directory not found. Please run this script from the project root."
        all_checks_passed=false
    fi
    
    if [ ! -d "web-frontend" ]; then # Assuming 'frontend' in original script meant 'web-frontend'
        log WARNING "Web Frontend directory not found. Skipping frontend build."
    fi
    
    if ! $all_checks_passed; then
        exit 1
    fi
    log SUCCESS "Prerequisites check passed."
}

# --------------------
# Build Functions
# --------------------

build_maven_project() {
    section "Building Maven Project (Backend)"
    
    (
        cd backend || exit 1
        # Use 'clean package' to ensure a fresh build and skip tests for faster deployment
        execute "mvn clean package -DskipTests" "Maven project built successfully."
    )
}

build_frontend_project() {
    section "Building Frontend Project (web-frontend)"
    
    local FRONTEND_DIR="web-frontend"
    
    if [ -d "$FRONTEND_DIR" ]; then
        (
            cd "$FRONTEND_DIR" || exit 1
            execute "npm install" "Frontend dependencies installed."
            execute "npm run build" "Frontend built successfully."
        )
    else
        log WARNING "Frontend directory '$FRONTEND_DIR' not found. Skipping frontend build."
    fi
}

# --------------------
# Deployment Function
# --------------------

deploy_with_compose() {
    section "Building and Deploying Services with Docker Compose"
    
    if [ ! -f "docker-compose.yml" ]; then
        log ERROR "docker-compose.yml not found in the root directory. Cannot deploy."
        exit 1
    fi
    
    # Use --wait for robust startup, ensuring services are healthy before continuing
    execute "docker-compose up --build -d --wait" "All services are up and running."
}

# --------------------
# Main Execution
# --------------------

main() {
    check_prerequisites
    
    build_maven_project
    build_frontend_project
    deploy_with_compose
    
    section "Deployment Summary"
    log SUCCESS "Full build and deployment process completed successfully."
}

main
