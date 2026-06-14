#!/bin/bash

# =====================================================
#   PayNext - Secure Service Management Script (Standalone)
# =====================================================
# This script provides a secure, standalone method to manage the lifecycle
# of individual backend services (build, start, stop) without relying on Docker Compose,
# adhering to financial industry standards for process control and logging.

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

# Function to display usage instructions
usage() {
    section "Usage Information"
    log INFO "Usage: $0 {build|start|stop|list} [service]"
    log INFO "Commands:"
    log INFO "  build             - Build all backend services"
    log INFO "  build <service>   - Build a specific backend service"
    log INFO "  start             - Start all backend services"
    log INFO "  start <service>   - Start a specific backend service"
    log INFO "  stop              - Stop all backend services"
    log INFO "  stop <service>    - Stop a specific backend service"
    log INFO "  list              - List all backend service PIDs and statuses"
    log INFO "Note: Frontend deployment is handled by separate scripts (e.g., manage-services.sh)."
    log INFO "Available Services:"
    for SERVICE in "${SERVICES[@]}"; do
        log INFO "  - $SERVICE"
    done
    exit 1
}

# --------------------
# Configuration
# --------------------

# Array of services to build and manage
SERVICES=(
    "eureka-server"
    "api-gateway"
    "user-service"
    "payment-service"
    "notification-service"
)

# Base directory where all services are located
BASE_DIR="$(pwd)/backend"

# Directory to store log files (Auditable)
LOG_DIR="$BASE_DIR/logs"

# Directory to store PID files (Process Control)
PID_DIR="$BASE_DIR/pids"

# Declare associative array for service ports (These should ideally be loaded from a secure config)
declare -A SERVICE_PORTS
SERVICE_PORTS=(
    ["eureka-server"]=8001
    ["api-gateway"]=8002
    ["user-service"]=8003
    ["payment-service"]=8004
    ["notification-service"]=8005
)

# --------------------
# Functions
# --------------------

# Function to check if a service is valid
is_valid_service() {
    local SERVICE="$1"
    for S in "${SERVICES[@]}"; do
        if [[ "$S" == "$SERVICE" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to build a single service
build_service() {
    local SERVICE="$1"
    section "Building $SERVICE"

    local SERVICE_PATH="$BASE_DIR/$SERVICE"
    if [ ! -d "$SERVICE_PATH" ]; then
        log ERROR "Directory $SERVICE_PATH not found."
        exit 1
    fi

    (
        cd "$SERVICE_PATH" || exit 1
        # Execute Maven build with clean install
        execute "mvn clean install" "Build failed for $SERVICE."
    )
    
    log SUCCESS "$SERVICE built successfully."
}

# Function to build all services
build_all_services() {
    section "Building All Backend Services"
    for SERVICE in "${SERVICES[@]}"; do
        build_service "$SERVICE"
    done
    log SUCCESS "All services built successfully."
}

# Function to check if a service is up by port
check_service_health() {
    local SERVICE_NAME="$1"
    local PORT="$2"
    local MAX_RETRIES=30          # Number of retries
    local RETRY_INTERVAL=5        # Seconds between retries

    log INFO "Checking health for $SERVICE_NAME on port $PORT..."

    for ((i=1;i<=MAX_RETRIES;i++)); do
        if nc -z 127.0.0.1 "$PORT"; then
            log SUCCESS "$SERVICE_NAME is up (Port $PORT)."
            return 0
        else
            echo -ne "\r$(date '+%H:%M:%S') [${YELLOW}WAIT${NC}] Waiting for $SERVICE_NAME to start... ($i/$MAX_RETRIES)"
            sleep "$RETRY_INTERVAL"
        fi
    done

    echo ""
    log ERROR "Failed to start $SERVICE_NAME after $MAX_RETRIES attempts."
    return 1
}

# Function to start a service
start_service() {
    local SERVICE="$1"
    local PORT="${SERVICE_PORTS[$SERVICE]}"
    local LOG_FILE="$LOG_DIR/$SERVICE.log"
    local PID_FILE="$PID_DIR/$SERVICE.pid"
    local SERVICE_PATH="$BASE_DIR/$SERVICE"

    # Check if the service is already running
    if [ -f "$PID_FILE" ]; then
        local EXISTING_PID
        EXISTING_PID=$(cat "$PID_FILE")
        if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
            log INFO "[$SERVICE] is already running with PID $EXISTING_PID."
            return
        else
            log WARNING "Found stale PID file for [$SERVICE]. Removing."
            rm -f "$PID_FILE"
        fi
    fi

    log INFO "Starting $SERVICE on port $PORT..."

    if [ ! -d "$SERVICE_PATH" ]; then
        log ERROR "Directory $SERVICE_PATH not found."
        exit 1
    fi

    (
        cd "$SERVICE_PATH" || exit 1
        # Start the service in the background using nohup with proper environment variables
        # Redirect output to a dedicated log file for audit
        nohup mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=$PORT" > "$LOG_FILE" 2>&1 &
        SERVICE_PID=$!
        echo "$SERVICE_PID" > "$PID_FILE"
        log INFO "[$SERVICE] started with PID $SERVICE_PID. Checking health..."
    )

    # Give the service a moment to initialize
    sleep 5

    # Check if the service is up
    if check_service_health "$SERVICE" "$PORT"; then
        log SUCCESS "[$SERVICE] started successfully."
    else
        log ERROR "Failed to start [$SERVICE]. Check $LOG_FILE for details."
        # Securely stop the service if health check fails
        kill "$SERVICE_PID" || true
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Function to stop a service
stop_service() {
    local SERVICE="$1"
    local PID_FILE="$PID_DIR/$SERVICE.pid"

    if [ ! -f "$PID_FILE" ]; then
        log INFO "[$SERVICE] is not running (no PID file found)."
        return
    fi

    local SERVICE_PID
    SERVICE_PID=$(cat "$PID_FILE")

    if ! ps -p "$SERVICE_PID" > /dev/null 2>&1; then
        log WARNING "[$SERVICE] process with PID $SERVICE_PID is not running. Removing stale PID file."
        rm -f "$PID_FILE"
        return
    fi

    log INFO "Stopping [$SERVICE] with PID $SERVICE_PID..."
    kill "$SERVICE_PID"

    # Wait for the process to terminate (Graceful shutdown)
    local WAIT_TIME=0
    local MAX_WAIT=30  # seconds
    while ps -p "$SERVICE_PID" > /dev/null 2>&1; do
        if [ "$WAIT_TIME" -ge "$MAX_WAIT" ]; then
            log ERROR "[$SERVICE] did not stop within $MAX_WAIT seconds. Sending SIGKILL (Force Stop)..."
            kill -9 "$SERVICE_PID"
            break
        fi
        sleep 1
        WAIT_TIME=$((WAIT_TIME + 1))
    done

    log SUCCESS "[$SERVICE] stopped."
    rm -f "$PID_FILE"
}

# Function to start all services
start_all_services() {
    section "Starting All Backend Services"
    for SERVICE in "${SERVICES[@]}"; do
        start_service "$SERVICE"
    done
    log SUCCESS "All services started successfully."
}

# Function to stop all services
stop_all_services() {
    section "Stopping All Backend Services"
    for SERVICE in "${SERVICES[@]}"; do
        stop_service "$SERVICE"
    done
    log SUCCESS "All services stopped successfully."
}

# Function to list all PIDs
list_pids() {
    section "Listing PIDs of All Managed Services"
    printf "%-20s %-10s %-10s\n" "Service" "PID" "Status"
    printf "%-20s %-10s %-10s\n" "-------" "---" "------"
    for SERVICE in "${SERVICES[@]}"; do
        local PID_FILE="$PID_DIR/$SERVICE.pid"
        local SERVICE_PID="N/A"
        local STATUS="Stopped"
        
        if [ -f "$PID_FILE" ]; then
            SERVICE_PID=$(cat "$PID_FILE")
            if ps -p "$SERVICE_PID" > /dev/null 2>&1; then
                STATUS="Running"
            else
                STATUS="Stopped (Stale PID)"
            fi
        fi
        printf "%-20s %-10s %-10s\n" "$SERVICE" "$SERVICE_PID" "$STATUS"
    done
}

# --------------------
# Main Script Logic
# --------------------

main() {
    # Ensure required commands are installed
    if ! command_exists mvn; then log ERROR "'mvn' command not found. Please install Maven."; exit 1; fi
    if ! command_exists nc; then log ERROR "'nc' command not found. Please install Netcat."; exit 1; fi
    
    # Create necessary directories
    mkdir -p "$LOG_DIR"
    mkdir -p "$PID_DIR"

    # Ensure at least one argument is provided
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        usage
    fi

    # Parse the command and optional service
    COMMAND="$1"
    SERVICE="${2:-}"

    case "$COMMAND" in
        build)
            if [ -n "$SERVICE" ]; then
                if is_valid_service "$SERVICE"; then
                    build_service "$SERVICE"
                else
                    log ERROR "Invalid service name: $SERVICE"
                    usage
                fi
            else
                build_all_services
            fi
            ;;
        start)
            if [ -n "$SERVICE" ]; then
                if is_valid_service "$SERVICE"; then
                    start_service "$SERVICE"
                else
                    log ERROR "Invalid service name: $SERVICE"
                    usage
                fi
            else
                start_all_services
            fi
            ;;
        stop)
            if [ -n "$SERVICE" ]; then
                if is_valid_service "$SERVICE"; then
                    stop_service "$SERVICE"
                else
                    log ERROR "Invalid service name: $SERVICE"
                    usage
                fi
            else
                stop_all_services
            fi
            ;;
        list)
            if [ -n "$SERVICE" ]; then
                log ERROR "'list' command does not take any arguments."
                usage
            fi
            list_pids
            ;;
        *)
            log ERROR "Invalid command: $COMMAND"
            usage
            ;;
    esac
}

# Invoke main with all script arguments
main "$@"
