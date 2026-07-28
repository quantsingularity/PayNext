#!/bin/bash

# =====================================================
#   PayNext - Secure Docker Build & Push Automation
# =====================================================
# This script automates the secure process of building, tagging,
# and pushing Docker images for services, adhering to financial
# industry standards for CI/CD and artifact management.

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

# Function to display usage information
usage() {
    section "Usage Information"
    log INFO "Usage: $0 <version_tag>"
    log INFO "Example: $0 1.0.0"
    log INFO "This script builds, tags, and securely pushes Docker images to a registry."
    log INFO "Requires DOCKER_USERNAME and DOCKER_PASSWORD environment variables to be set."
    exit 1
}

# --------------------
# Main Logic
# --------------------

# Check for required arguments
if [ "$#" -ne 1 ]; then
    usage
fi

VERSION_TAG="$1"

# Check prerequisites
section "Prerequisites Check"
if ! command_exists docker; then
    log ERROR "Docker is not installed. Please install Docker before running this script."
    exit 1
fi

if ! command_exists git; then
    log ERROR "Git is not installed. Please install Git before running this script."
    exit 1
fi

if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    log ERROR "This script must be run inside a Git repository."
    exit 1
fi

# Security: Check for Docker credentials
if [ -z "${DOCKER_USERNAME:-}" ] || [ -z "${DOCKER_PASSWORD:-}" ]; then
    log ERROR "Docker credentials are not set. Please set DOCKER_USERNAME and DOCKER_PASSWORD in your environment variables."
    log ERROR "In a secure environment, consider using a short-lived token or a secret manager."
    exit 1
fi

# Log in to Docker Hub securely
section "Docker Registry Login"
# Suppress output to prevent password from being logged, even if it's via stdin
if ! echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin &> /dev/null; then
    log ERROR "Failed to log in to Docker Hub. Check credentials."
    exit 1
fi
log SUCCESS "Successfully logged in to Docker Hub."

# Define Docker Hub repositories
DOCKER_REPO_PREFIX="$DOCKER_USERNAME/paynext"

# Services to build and push
BACKEND_SERVICES=("eureka-server" "api-gateway" "user-service" "payment-service" "notification-service")
FRONTEND_SERVICE="web-frontend" # Assuming 'frontend' in original script meant 'web-frontend'

# Function to build and push a Docker image
build_and_push() {
    local SERVICE_NAME="$1"
    local SERVICE_PATH="$2"
    local IMAGE_TAG="$3"
    local FULL_IMAGE_NAME="$DOCKER_REPO_PREFIX-$SERVICE_NAME:$IMAGE_TAG"

    log INFO "----------------------------------------"
    log INFO "Processing service: $SERVICE_NAME"

    # Check if service directory exists
    if [ ! -d "$SERVICE_PATH" ]; then
        log WARNING "Directory $SERVICE_PATH does not exist. Skipping $SERVICE_NAME."
        return 0
    fi

    # Build Docker image
    log INFO "Building Docker image for $SERVICE_NAME with tag $IMAGE_TAG..."
    # Use execute for robust error handling
    if ! execute "docker build -t \"$FULL_IMAGE_NAME\" \"$SERVICE_PATH\"" "Successfully built $FULL_IMAGE_NAME" true; then
        log ERROR "Docker build failed for $SERVICE_NAME. Continuing to next service."
        return 1
    fi

    # Push Docker image to Docker Hub
    log INFO "Pushing Docker image $FULL_IMAGE_NAME to registry..."
    if ! execute "docker push \"$FULL_IMAGE_NAME\"" "Successfully pushed $FULL_IMAGE_NAME" true; then
        log ERROR "Docker push failed for $SERVICE_NAME. Continuing to next service."
        return 1
    fi
    
    log SUCCESS "Finished processing $SERVICE_NAME."
    return 0
}

# Build and push backend services
section "Building and Pushing Backend Services"
for SERVICE in "${BACKEND_SERVICES[@]}"
do
    SERVICE_PATH="./backend/$SERVICE"
    build_and_push "$SERVICE" "$SERVICE_PATH" "$VERSION_TAG"
done

# Build and push frontend service
section "Building and Pushing Frontend Service"
FRONTEND_PATH="./$FRONTEND_SERVICE"
build_and_push "$FRONTEND_SERVICE" "$FRONTEND_PATH" "$VERSION_TAG"

# Security: Logout from Docker Hub immediately after use
section "Docker Registry Logout"
if ! docker logout &> /dev/null; then
    log WARNING "Docker logout failed. Manual intervention may be required."
else
    log SUCCESS "Successfully logged out from Docker Hub."
fi

section "Build and Push Summary"
log SUCCESS "All specified Docker images have been processed."
log INFO "Images are tagged with: $VERSION_TAG"
