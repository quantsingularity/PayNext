#!/bin/bash

# =====================================================
#   PayNext - Secure Single Service Startup Script
# =====================================================
# This script provides a secure and auditable way to start a single backend
# service from its JAR file, adhering to financial industry standards for
# process control and logging.

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

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display usage information
usage() {
    section "Usage Information"
    log INFO "Usage: $0 <service-name>"
    log INFO "Starts a single backend service from its JAR file."
    log INFO "Available Services:"
    log INFO "  - eureka-server"
    log INFO "  - api-gateway"
    log INFO "  - user-service"
    log INFO "  - payment-service"
    log INFO "  - notification-service"
    exit 1
}

# --------------------
# Main Logic
# --------------------

# Check for required arguments
if [ "$#" -ne 1 ]; then
    usage
fi

SERVICE_NAME="$1"
JAR_FILE="$SERVICE_NAME.jar"
SERVICE_PATH="./backend/$SERVICE_NAME"

# Check prerequisites
section "Prerequisites Check"
if ! command_exists java; then
    log ERROR "Java is not installed. Please install Java Runtime Environment."
    exit 1
fi

if [ ! -d "$SERVICE_PATH" ]; then
    log ERROR "Service directory not found: $SERVICE_PATH"
    exit 1
fi

# Navigate to the service directory to find the JAR
(
    cd "$SERVICE_PATH" || exit 1
    
    # Check for the JAR file (assuming it's built to 'target' or similar)
    # This is a common pattern, but the exact path might need adjustment
    if [ -f "target/$JAR_FILE" ]; then
        JAR_PATH="target/$JAR_FILE"
    elif [ -f "$JAR_FILE" ]; then
        JAR_PATH="$JAR_FILE"
    else
        log ERROR "JAR file not found for $SERVICE_NAME. Please ensure the service is built."
        exit 1
    fi
    
    section "Starting $SERVICE_NAME"
    log INFO "Starting service from: $JAR_PATH"
    
    # Securely execute the JAR file
    # In a production environment, this would be run by a dedicated, non-root user
    # and managed by a process supervisor (e.g., systemd, supervisord).
    # For a simple script, we run it directly.
    log INFO "Running: java -jar $JAR_PATH"
    
    # Execute the service. This will block the script until the service is stopped.
    # The original script ran this way, so we maintain the behavior.
    if java -jar "$JAR_PATH"; then
        log SUCCESS "$SERVICE_NAME stopped gracefully."
    else
        log ERROR "$SERVICE_NAME terminated with an error."
        exit 1
    fi
)

log SUCCESS "Script finished execution."
