#!/usr/bin/env bash

# =====================================================
#   PayNext - Secure All-Component Test Runner
# =====================================================
# This script automates the execution of all test suites across the project,
# with enhanced logging, robust error handling, and a clear summary,
# adhering to financial industry standards for quality assurance and auditability.

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
print_header() {
    log INFO "======================================================================="
    log INFO " $1"
    log INFO "======================================================================="
}

# --------------------
# Configuration
# --------------------

# Default to script’s directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_BASE_DIR="$(dirname "$SCRIPT_DIR")" # Assuming scripts_optimized is one level deep

# Parse flags
while getopts ":d:" opt; do
  case ${opt} in
    d) PROJECT_BASE_DIR="$OPTARG" ;;
    *) log ERROR "Usage: $0 [-d project_base_dir]"; exit 1 ;;
  esac
done

# Component paths (relative to PROJECT_BASE_DIR)
declare -A COMPONENT_DIRS=(
  [payment-service]="backend/payment-service"
  [user-service]="backend/user-service"
  [web-frontend]="web-frontend"
  [mobile-frontend]="mobile-frontend"
  # Add other services as needed
  [eureka-server]="backend/eureka-server"
  [api-gateway]="backend/api-gateway"
  [notification-service]="backend/notification-service"
)

# Track failures and durations
any_failed=false
declare -A durations
declare -A test_status

# Directory to store logs and reports (Auditable)
LOG_DIR="$PROJECT_BASE_DIR/test-logs"
REPORT_DIR="$PROJECT_BASE_DIR/test-reports"

# Create log and report directories
mkdir -p "$LOG_DIR"
mkdir -p "$REPORT_DIR"

# --------------------
# Main Test Function
# --------------------

run_tests() {
    local name="$1"
    local relpath="$2"
    local fullpath="$PROJECT_BASE_DIR/$relpath"
    local start end elapsed cmd logfile
    
    print_header "Component: $name"
    
    if [[ ! -d "$fullpath" ]]; then
        log WARNING "SKIP: Directory not found: $relpath"
        test_status["$name"]="SKIPPED"
        return
    fi

    # Determine test command based on build file (Robustness)
    if [[ -f "$fullpath/pom.xml" ]]; then
        # Maven project: run all tests (unit and integration)
        cmd="mvn clean verify"
    elif [[ -f "$fullpath/build.gradle" ]]; then
        # Gradle project
        if [[ -x "$fullpath/gradlew" ]]; then
            cmd="./gradlew clean test"
        else
            cmd="gradle clean test"
        fi
    elif [[ -f "$fullpath/package.json" ]]; then
        # Node.js project: ensure dependencies are installed first
        local package_manager="npm"
        if [[ -f "$fullpath/pnpm-lock.yaml" ]]; then
            package_manager="pnpm"
        elif [[ -f "$fullpath/yarn.lock" ]]; then
            package_manager="yarn"
        fi
        
        # Use a subshell to run install and test
        cmd="$package_manager install && $package_manager test"
    else
        log WARNING "SKIP: No recognized build file (pom.xml, build.gradle, package.json) in $relpath"
        test_status["$name"]="SKIPPED"
        return
    fi

    log INFO "Executing in $relpath: $cmd"
    logfile="$LOG_DIR/${name}.log"
    start=$(date +%s)
    
    # Execute command in a subshell, redirecting all output to the logfile
    if (cd "$fullpath" && bash -lc "$cmd" &> "$logfile"); then
        end=$(date +%s)
        elapsed=$((end - start))
        durations["$name"]="$elapsed"
        test_status["$name"]="PASS"
        log SUCCESS "PASS: $name in ${elapsed}s"
    else
        end=$(date +%s)
        elapsed=$((end - start))
        durations["$name"]="$elapsed"
        test_status["$name"]="FAIL"
        any_failed=true
        log ERROR "FAIL: $name in ${elapsed}s"
        log INFO "  → See $logfile for details"
    fi
    
    # Copy reports for audit (Auditable)
    if [[ -d "$fullpath/target/surefire-reports" ]]; then
        cp -r "$fullpath/target/surefire-reports" "$REPORT_DIR/$name-surefire"
    fi
    if [[ -d "$fullpath/target/failsafe-reports" ]]; then
        cp -r "$fullpath/target/failsafe-reports" "$REPORT_DIR/$name-failsafe"
    fi
    if [[ -d "$fullpath/coverage" ]]; then
        cp -r "$fullpath/coverage" "$REPORT_DIR/$name-coverage"
    fi
}

# --------------------
# Execution and Summary
# --------------------

main() {
    print_header "Starting All Component Test Run"
    
    # Run tests for all defined components
    for comp in "${!COMPONENT_DIRS[@]}"; do
        run_tests "$comp" "${COMPONENT_DIRS[$comp]}"
    done
    
    # Summary
    print_header "Test Summary (Audit Report)"
    
    # Print header
    printf "%-20s %-10s %-10s\n" "Component" "Status" "Duration (s)"
    printf "%-20s %-10s %-10s\n" "---------" "------" "------------"
    
    # Print results
    for comp in "${!COMPONENT_DIRS[@]}"; do
        local status="${test_status[$comp]:-NOT RUN}"
        local duration="${durations[$comp]:-N/A}"
        local color="$NC"
        
        case "$status" in
            PASS) color="$GREEN" ;;
            FAIL) color="$RED" ;;
            SKIPPED) color="$YELLOW" ;;
        esac
        
        printf "${color}%-20s %-10s %-10s${NC}\n" "$comp" "$status" "$duration"
    done
    
    if $any_failed; then
        log ERROR "\nOne or more test suites failed. Check logs in $LOG_DIR and reports in $REPORT_DIR."
        exit 1
    else
        log SUCCESS "\nAll test suites passed successfully! System is compliant."
        exit 0
    fi
}

main
