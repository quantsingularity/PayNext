#!/bin/bash

# =====================================================
#   PayNext - Secure Build and Compose Management
# =====================================================
# This script manages the build and deployment of services using Docker Compose,
# with enhanced security, logging, and robustness for a financial environment.

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

# Function to display usage
usage() {
    section "Usage Information"
    log INFO "Usage: $0 {build|start|stop|all}"
    log INFO "  build - Builds backend services, frontend, and Docker images."
    log INFO "  start - Starts all services using Docker Compose."
    log INFO "  stop  - Stops all services using Docker Compose."
    log INFO "  all   - Builds and starts all services."
    exit 1
}

# --------------------
# Configuration
# --------------------

# Define project root
PROJECT_ROOT=$(pwd)

# Define backend and frontend directories (Corrected 'frontend' to 'web-frontend' based on repo structure)
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/web-frontend"

# Define backend services
BACKEND_SERVICES=("eureka-server" "api-gateway" "user-service" "payment-service" "notification-service")

# --------------------
# Prerequisites Check
# --------------------

check_prerequisites() {
    section "Prerequisites Check"
    local all_checks_passed=true
    
    if ! command_exists docker; then
        log ERROR "Docker could not be found. Please install Docker before running this script."
        all_checks_passed=false
    fi
    
    if ! command_exists docker-compose; then
        log ERROR "Docker Compose could not be found. Please install Docker Compose before running this script."
        all_checks_passed=false
    fi
    
    if [ ! -d "$BACKEND_DIR" ]; then
        log ERROR "Backend directory not found: $BACKEND_DIR. Please run this script from the project root."
        all_checks_passed=false
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log WARNING "Web Frontend directory not found: $FRONTEND_DIR. Skipping frontend build."
    fi
    
    if ! $all_checks_passed; then
        exit 1
    fi
    log SUCCESS "Prerequisites check passed."
}

# --------------------
# Build Functions
# --------------------

# Function to build backend services
build_backend_services() {
    section "Building Backend Services (Maven)"

    for SERVICE in "${BACKEND_SERVICES[@]}"
    do
        local SERVICE_PATH="$BACKEND_DIR/$SERVICE"
        log INFO "Processing $SERVICE..."

        if [ -d "$SERVICE_PATH" ]; then
            (
                cd "$SERVICE_PATH" || exit 1
                # Use -DskipTests to speed up build, tests should be run separately
                execute "mvn clean install -DskipTests" "$SERVICE built successfully."
            )
        else
            log ERROR "Directory $SERVICE_PATH does not exist. Skipping $SERVICE."
        fi
    done
    log SUCCESS "All backend services processed."
}

# Function to build frontend
build_frontend() {
    section "Building Frontend (npm)"

    if [ -d "$FRONTEND_DIR" ]; then
        (
            cd "$FRONTEND_DIR" || exit 1
            # Use execute for robust error handling
            execute "npm install" "Frontend dependencies installed."
            execute "npm run build" "Frontend built successfully."
        )
    else
        log WARNING "Frontend directory $FRONTEND_DIR does not exist. Skipping frontend build."
    fi
}

# Function to build Docker images
build_docker_images() {
    section "Building Docker Images"
    local DOCKER_TAG="1.0.0" # Use a fixed tag for local compose, or pass as argument

    for SERVICE in "${BACKEND_SERVICES[@]}"
    do
        local SERVICE_PATH="$BACKEND_DIR/$SERVICE"
        log INFO "Building Docker image for $SERVICE..."

        if [ -d "$SERVICE_PATH" ]; then
            (
                cd "$SERVICE_PATH" || exit 1
                # Use execute for robust error handling
                execute "docker build -t fintech/$SERVICE:$DOCKER_TAG ." "Docker image for $SERVICE built successfully."
            )
        else
            log ERROR "Directory $SERVICE_PATH does not exist. Skipping Docker build for $SERVICE."
        fi
    done

    # Build Docker image for frontend
    log INFO "Building Docker image for web-frontend..."
    if [ -d "$FRONTEND_DIR" ]; then
        (
            cd "$FRONTEND_DIR" || exit 1
            execute "docker build -t fintech/web-frontend:$DOCKER_TAG ." "Docker image for web-frontend built successfully."
        )
    else
        log WARNING "Web Frontend directory $FRONTEND_DIR does not exist. Skipping Docker build for web-frontend."
    fi
    log SUCCESS "All specified Docker images processed."
}

# --------------------
# Compose Functions
# --------------------

# Function to start all services using Docker Compose
start_services() {
    section "Starting All Services with Docker Compose"

    local COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        # Use --wait for robust startup, ensuring services are healthy before continuing
        execute "docker-compose up -d --build --wait" "All services started and healthy."
    else
        log ERROR "docker-compose.yml not found in the root directory. Cannot start services."
        exit 1
    fi
}

# Function to stop all services using Docker Compose
stop_services() {
    section "Stopping All Services with Docker Compose"

    local COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        execute "docker-compose down" "All services stopped successfully."
    else
        log WARNING "docker-compose.yml not found. Attempting to stop existing containers."
        # Fallback to stop containers if compose file is missing
        execute "docker stop \$(docker ps -a -q --filter name=paynext)" "Existing PayNext containers stopped." true
        execute "docker rm \$(docker ps -a -q --filter name=paynext)" "Existing PayNext containers removed." true
    fi
}

# --------------------
# Main Execution
# --------------------

main() {
    check_prerequisites

    # Parse command-line arguments
    case "${1:-}" in
        build)
            build_backend_services
            build_frontend
            build_docker_images
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        all)
            build_backend_services
            build_frontend
            build_docker_images
            start_services
            ;;
        *)
            usage
            ;;
    esac
}

# Invoke main with all script arguments
main "$@"
