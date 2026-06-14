#!/bin/bash

# =====================================================
#   PayNext - Secure Kubernetes Deployment Automation
# =====================================================
# This script automates the secure build and deployment of a single service
# to a local Kubernetes environment (Minikube), with enhanced security,
# logging, and robustness for a financial environment.

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
    log INFO "Usage: $0 <service-name>"
    log INFO "Example: $0 user-service"
    log INFO "Deploys a specified service to the local Minikube cluster."
    exit 1
}

# --------------------
# Configuration
# --------------------

MINIKUBE_PROFILE="paynext-dev" # Use a specific profile name for isolation
K8S_TEMPLATES_DIR="kubernetes/templates"

# --------------------
# Main Logic
# --------------------

# Check for required arguments
if [ "$#" -ne 1 ]; then
    usage
fi

SERVICE_NAME="$1"

# Check prerequisites
section "Prerequisites Check"
if ! command_exists minikube; then
    log ERROR "Minikube is not installed. Please install Minikube."
    exit 1
fi
if ! command_exists kubectl; then
    log ERROR "kubectl is not installed. Please install kubectl."
    exit 1
fi
if ! command_exists docker; then
    log ERROR "Docker is not installed. Please install Docker."
    exit 1
fi

# Start Minikube
section "Minikube Setup"
log INFO "Checking if Minikube is already running with profile $MINIKUBE_PROFILE..."
if minikube status --profile="$MINIKUBE_PROFILE" | grep -q "Running"; then
    log SUCCESS "Minikube is already running. Skipping start."
else
    log INFO "Starting Minikube with profile $MINIKUBE_PROFILE..."
    execute "minikube start --profile=$MINIKUBE_PROFILE" "Minikube started successfully."
fi

# Configure shell to use Minikube's Docker daemon
section "Configuring Docker Environment"
log INFO "Using Minikube's Docker environment for image build..."
# The eval command is necessary but must be executed carefully
# shellcheck disable=SC2046
if ! eval $(minikube -p "$MINIKUBE_PROFILE" docker-env); then
    log ERROR "Failed to configure shell to use Minikube's Docker daemon."
    exit 1
fi
log SUCCESS "Docker environment configured."

# Build Docker image
section "Building Docker Image for $SERVICE_NAME"
# Determine service path and image name
if [[ "$SERVICE_NAME" == "frontend" ]]; then
    SERVICE_PATH="web-frontend" # Assuming 'frontend' maps to 'web-frontend'
else
    SERVICE_PATH="backend/$SERVICE_NAME"
fi

IMAGE_NAME="fintech-$SERVICE_NAME:latest"

if [ ! -d "$SERVICE_PATH" ]; then
    log ERROR "Service directory not found: $SERVICE_PATH. Cannot build image."
    exit 1
fi

# Use execute for robust build process
execute "docker build -t \"$IMAGE_NAME\" \"$SERVICE_PATH\"" "Docker image built successfully: $IMAGE_NAME"

# Deploy to Kubernetes
section "Deploying $SERVICE_NAME to Kubernetes"

# Define the deployment and service YAML files
DEPLOYMENT_FILE="$K8S_TEMPLATES_DIR/deployment-$SERVICE_NAME.yaml"
SERVICE_FILE="$K8S_TEMPLATES_DIR/service-$SERVICE_NAME.yaml"

# Check if the deployment files exist
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    log ERROR "Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi
if [ ! -f "$SERVICE_FILE" ]; then
    log ERROR "Service file not found: $SERVICE_FILE"
    exit 1
fi

# Apply the deployment and service
execute "kubectl apply -f \"$DEPLOYMENT_FILE\"" "Deployment for $SERVICE_NAME applied successfully."
execute "kubectl apply -f \"$SERVICE_FILE\"" "Service for $SERVICE_NAME applied successfully."

log SUCCESS "$SERVICE_NAME deployed successfully on Minikube."
