#!/bin/bash

# =====================================================
#   PayNext - Secure Service Management Script
# =====================================================
# This script provides a centralized, secure, and auditable way to manage
# individual services (clean, build, run) within the PayNext architecture,
# adhering to financial industry standards for service lifecycle management.

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

# Function to display usage information
usage() {
    section "Usage Information"
    log INFO "Usage: $0 <command> <service-name|all>"
    log INFO "Commands: clean | build | run"
    log INFO "Services: backend-service-name | ml-service-name | frontend-service-name | all"
    log INFO "Example: $0 build user-service"
    log INFO "Example: $0 run all"
    exit 1
}

# --------------------
# Configuration
# --------------------

# Define project root
PROJECT_ROOT=$(pwd)

# Define backend and frontend directories (Corrected 'frontend' to 'web-frontend' based on repo structure)
BACKEND_DIR="$PROJECT_ROOT/backend"
WEB_FRONTEND_DIR="$PROJECT_ROOT/web-frontend"
MOBILE_FRONTEND_DIR="$PROJECT_ROOT/mobile-frontend"
ML_SERVICES_DIR="$PROJECT_ROOT/ml_services"

# Define services for clear mapping
BACKEND_SERVICES=("eureka-server" "api-gateway" "user-service" "payment-service" "notification-service")
ML_SERVICES=("fraud-detection-service" "churn-prediction-service" "recommendation-service" "categorization-service" "credit-scoring-service")
FRONTEND_SERVICES=("web-frontend" "mobile-frontend")

# --------------------
# Prerequisites Check
# --------------------

check_prerequisites() {
    section "Prerequisites Check"
    local all_checks_passed=true
    
    if ! command_exists docker; then
        log ERROR "Docker could not be found. Required for 'run' command."
        all_checks_passed=false
    fi
    
    if ! command_exists docker-compose; then
        log ERROR "Docker Compose could not be found. Required for 'run' command."
        all_checks_passed=false
    fi
    
    if ! command_exists mvn; then
        log WARNING "Maven (mvn) not found. Backend 'build' and 'clean' commands will fail."
    fi
    
    if ! command_exists npm; then
        log WARNING "npm not found. Frontend 'build' and 'clean' commands will fail."
    fi
    
    if ! $all_checks_passed; then
        exit 1
    fi
    log SUCCESS "Prerequisites check passed."
}

# --------------------
# Backend Functions (Java/Maven)
# --------------------

clean_backend() {
    local SERVICE="$1"
    local SERVICE_DIR="$BACKEND_DIR/$SERVICE"

    if [ -d "$SERVICE_DIR" ]; then
        log INFO "Cleaning backend service: $SERVICE"
        (
            cd "$SERVICE_DIR" || exit 1
            execute "mvn clean" "Backend service '$SERVICE' cleaned successfully."
        )
    else
        log ERROR "Backend service directory '$SERVICE_DIR' does not exist."
        exit 1
    fi
}

build_backend() {
    local SERVICE="$1"
    local SERVICE_DIR="$BACKEND_DIR/$SERVICE"

    if [ -d "$SERVICE_DIR" ]; then
        log INFO "Building backend service: $SERVICE"
        (
            cd "$SERVICE_DIR" || exit 1
            # Skip tests for faster build, tests should be run separately
            execute "mvn clean install -DskipTests" "Backend service '$SERVICE' built successfully."
        )
    else
        log ERROR "Backend service directory '$SERVICE_DIR' does not exist."
        exit 1
    fi
}

run_backend() {
    local SERVICE="$1"
    log INFO "Running backend service: $SERVICE via Docker Compose"
    (
        cd "$PROJECT_ROOT" || exit 1
        # Use --build to ensure the latest image is used
        execute "docker-compose up -d --build \"$SERVICE\"" "Backend service '$SERVICE' is now running."
    )
}

# --------------------
# ML Service Functions (Python/Docker)
# --------------------

# ML services are typically managed via Docker, so clean/build is often a Docker build
build_ml_service() {
    local SERVICE="$1"
    local SERVICE_DIR="$ML_SERVICES_DIR/$SERVICE"

    if [ -d "$SERVICE_DIR" ]; then
        log INFO "Building ML service: $SERVICE (Docker Build)"
        (
            cd "$SERVICE_DIR" || exit 1
            # Assuming a Dockerfile exists in the ML service directory
            execute "docker build -t paynext-ml/$SERVICE:latest ." "ML service '$SERVICE' built successfully."
        )
    else
        log ERROR "ML service directory '$SERVICE_DIR' does not exist."
        exit 1
    fi
}

run_ml_service() {
    local SERVICE="$1"
    log INFO "Running ML service: $SERVICE via Docker Compose"
    (
        cd "$PROJECT_ROOT" || exit 1
        execute "docker-compose up -d --build \"$SERVICE\"" "ML service '$SERVICE' is now running."
    )
}

# --------------------
# Frontend Functions (Node/npm)
# --------------------

clean_frontend() {
    local SERVICE="$1"
    local SERVICE_DIR=""
    
    if [ "$SERVICE" == "web-frontend" ]; then
        SERVICE_DIR="$WEB_FRONTEND_DIR"
    elif [ "$SERVICE" == "mobile-frontend" ]; then
        SERVICE_DIR="$MOBILE_FRONTEND_DIR"
    fi

    if [ -d "$SERVICE_DIR" ]; then
        log INFO "Cleaning frontend service: $SERVICE"
        (
            cd "$SERVICE_DIR" || exit 1
            # Securely remove node_modules and build directories
            execute "rm -rf node_modules build dist" "Frontend service '$SERVICE' cleaned successfully."
        )
    else
        log ERROR "Frontend service directory '$SERVICE_DIR' does not exist."
        exit 1
    fi
}

build_frontend() {
    local SERVICE="$1"
    local SERVICE_DIR=""
    
    if [ "$SERVICE" == "web-frontend" ]; then
        SERVICE_DIR="$WEB_FRONTEND_DIR"
    elif [ "$SERVICE" == "mobile-frontend" ]; then
        SERVICE_DIR="$MOBILE_FRONTEND_DIR"
    fi

    if [ -d "$SERVICE_DIR" ]; then
        log INFO "Building frontend service: $SERVICE"
        (
            cd "$SERVICE_DIR" || exit 1
            execute "npm install" "Frontend dependencies installed."
            execute "npm run build" "Frontend service '$SERVICE' built successfully."
        )
    else
        log ERROR "Frontend service directory '$SERVICE_DIR' does not exist."
        exit 1
    fi
}

run_frontend() {
    local SERVICE="$1"
    log INFO "Running frontend service: $SERVICE via Docker Compose"
    (
        cd "$PROJECT_ROOT" || exit 1
        execute "docker-compose up -d --build \"$SERVICE\"" "Frontend service '$SERVICE' is now running."
    )
}

# --------------------
# All Services Functions
# --------------------

all_services() {
    local ACTION="$1"
    section "Performing '$ACTION' on All Services"

    # Backend Services
    for service in "${BACKEND_SERVICES[@]}"; do
        case "$ACTION" in
            clean) clean_backend "$service" ;;
            build) build_backend "$service" ;;
            run) run_backend "$service" ;;
        esac
    done

    # ML Services (Only build and run supported)
    for service in "${ML_SERVICES[@]}"; do
        case "$ACTION" in
            build) build_ml_service "$service" ;;
            run) run_ml_service "$service" ;;
        esac
    done

    # Frontend Services
    for service in "${FRONTEND_SERVICES[@]}"; do
        case "$ACTION" in
            clean) clean_frontend "$service" ;;
            build) build_frontend "$service" ;;
            run) run_frontend "$service" ;;
        esac
    done
    
    log SUCCESS "Action '$ACTION' completed for all services."
}

# --------------------
# Main Execution
# --------------------

main() {
    check_prerequisites

    if [ "$#" -ne 2 ]; then
        usage
    fi

    local COMMAND="$1"
    local SERVICE="$2"

    if [ "$SERVICE" == "all" ]; then
        all_services "$COMMAND"
        exit 0
    fi

    # Determine service type and execute command
    if [[ " ${BACKEND_SERVICES[*]} " == *" ${SERVICE} "* ]]; then
        case "$COMMAND" in
            clean) clean_backend "$SERVICE" ;;
            build) build_backend "$SERVICE" ;;
            run) run_backend "$SERVICE" ;;
            *) log ERROR "Invalid command '$COMMAND' for backend service." && usage ;;
        esac
    elif [[ " ${ML_SERVICES[*]} " == *" ${SERVICE} "* ]]; then
        case "$COMMAND" in
            build) build_ml_service "$SERVICE" ;;
            run) run_ml_service "$SERVICE" ;;
            *) log ERROR "Invalid command '$COMMAND' for ML service (only build and run supported)." && usage ;;
        esac
    elif [[ " ${FRONTEND_SERVICES[*]} " == *" ${SERVICE} "* ]]; then
        case "$COMMAND" in
            clean) clean_frontend "$SERVICE" ;;
            build) build_frontend "$SERVICE" ;;
            run) run_frontend "$SERVICE" ;;
            *) log ERROR "Invalid command '$COMMAND' for frontend service." && usage ;;
        esac
    else
        log ERROR "Service '$SERVICE' not recognized."
        usage
    fi
}

# Invoke main with all script arguments
main "$@"
