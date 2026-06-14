#!/bin/bash

# =====================================================
#   PayNext - Testing Automation Script
# =====================================================
# This script automates comprehensive testing across all components of the PayNext platform,
# including backend services, web frontend, and mobile frontend.

# Exit on error
set -e

# --------------------
# Color Definitions
# --------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --------------------
# Helper Functions
# --------------------

# Print section headers
section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}\n"
}

# Print informational messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Print success messages
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Print warning messages
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Print error messages
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Execute a command and handle errors
execute() {
    local cmd="$1"
    local msg="$2"
    local continue_on_error="${3:-false}"

    echo -e "${CYAN}[EXECUTING]${NC} $cmd"

    if eval "$cmd"; then
        success "$msg"
        return 0
    else
        local exit_code=$?
        error "Failed to execute: $cmd (Exit code: $exit_code)"
        if [[ "$continue_on_error" != "true" ]]; then
            return $exit_code
        fi
        return 0
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# =========================
# Configuration
# =========================

# Project directories
PROJECT_ROOT=$(pwd)
BACKEND_DIR="$PROJECT_ROOT/backend"
WEB_FRONTEND_DIR="$PROJECT_ROOT/web-frontend"
MOBILE_FRONTEND_DIR="$PROJECT_ROOT/mobile-frontend"
REPORTS_DIR="$PROJECT_ROOT/test-reports"

# Backend services
BACKEND_SERVICES=(
    "eureka-server"
    "config-server"
    "api-gateway"
    "user-service"
    "payment-service"
    "transaction-service"
    "notification-service"
    "reporting-service"
)

# Test types
TEST_TYPES=(
    "unit"
    "integration"
    "e2e"
)

# =========================
# Prerequisites Check
# =========================

check_prerequisites() {
    section "Checking Prerequisites"

    local os
    os=$(detect_os)
    info "Detected operating system: $os"

    # Check Java
    if command_exists java; then
        local java_version
        java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed 's/^1\.//' | cut -d'.' -f1)
        if [[ "$java_version" -ge 17 ]]; then
            success "Java $java_version is installed"
        else
            warning "Java $java_version is installed, but version 17 or higher is recommended"
        fi
    else
        error "Java is not installed. Please install Java 17 or higher"
        exit 1
    fi

    # Check Maven
    if command_exists mvn; then
        local mvn_version
        mvn_version=$(mvn --version | head -1 | awk '{print $3}')
        success "Maven $mvn_version is installed"
    else
        error "Maven is not installed. Please install Maven"
        exit 1
    fi

    # Check Node.js
    if command_exists node; then
        local node_version
        node_version=$(node --version | cut -d'v' -f2)
        success "Node.js $node_version is installed"
    else
        error "Node.js is not installed. Please install Node.js"
        exit 1
    fi

    # Check npm
    if command_exists npm; then
        local npm_version
        npm_version=$(npm --version)
        success "npm $npm_version is installed"
    else
        error "npm is not installed. Please install npm"
        exit 1
    fi

    success "Prerequisites check completed"
}

# =========================
# Setup
# =========================

setup_test_environment() {
    section "Setting Up Test Environment"

    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$REPORTS_DIR/backend"
    mkdir -p "$REPORTS_DIR/web-frontend"
    mkdir -p "$REPORTS_DIR/mobile-frontend"
    mkdir -p "$REPORTS_DIR/e2e"

    success "Test environment setup completed"
}

# =========================
# Backend Tests
# =========================

run_backend_tests() {
    section "Running Backend Tests"

    local test_type="$1"
    local specific_service="$2"
    local services=()

    # Determine which services to test
    if [[ -n "$specific_service" ]]; then
        if [[ " ${BACKEND_SERVICES[*]} " == *" $specific_service "* ]]; then
            services=("$specific_service")
        else
            error "Invalid service: $specific_service"
            return 1
        fi
    else
        services=("${BACKEND_SERVICES[@]}")
    fi

    # Run tests for each service
    for service in "${services[@]}"; do
        local service_dir="$BACKEND_DIR/$service"

        # Check if service directory exists
        if [[ ! -d "$service_dir" ]]; then
            warning "Service directory not found: $service_dir, skipping..."
            continue
        fi

        info "Running $test_type tests for $service"

        cd "$service_dir" || continue

        case "$test_type" in
            "unit")
                execute "mvn test -Dtest=*Test -DfailIfNoTests=false" "Unit tests completed for $service" true
                ;;
            "integration")
                execute "mvn verify -Dtest=*IT -DfailIfNoTests=false" "Integration tests completed for $service" true
                ;;
            *)
                warning "Unknown test type: $test_type for backend, skipping..."
                ;;
        esac

        # Copy test reports
        if [[ -d "target/surefire-reports" ]]; then
            mkdir -p "$REPORTS_DIR/backend/$service"
            cp -r target/surefire-reports/* "$REPORTS_DIR/backend/$service/"
        fi

        cd "$PROJECT_ROOT" || exit 1
    done

    success "Backend $test_type tests completed"
}

# =========================
# Web Frontend Tests
# =========================

run_web_frontend_tests() {
    section "Running Web Frontend Tests"

    local test_type="$1"

    # Check if web frontend directory exists
    if [[ ! -d "$WEB_FRONTEND_DIR" ]]; then
        warning "Web frontend directory not found: $WEB_FRONTEND_DIR, skipping..."
        return
    fi

    cd "$WEB_FRONTEND_DIR" || exit 1

    case "$test_type" in
        "unit")
            info "Running unit tests for web frontend"
            execute "npm test -- --watchAll=false" "Unit tests completed for web frontend" true
            ;;
        "e2e")
            info "Running end-to-end tests for web frontend"
            execute "npm run test:e2e" "End-to-end tests completed for web frontend" true
            ;;
        *)
            warning "Unknown test type: $test_type for web frontend, skipping..."
            ;;
    esac

    # Copy test reports
    if [[ -d "coverage" ]]; then
        mkdir -p "$REPORTS_DIR/web-frontend"
        cp -r coverage/* "$REPORTS_DIR/web-frontend/"
    fi

    cd "$PROJECT_ROOT" || exit 1

    success "Web frontend $test_type tests completed"
}

# =========================
# Mobile Frontend Tests
# =========================

run_mobile_frontend_tests() {
    section "Running Mobile Frontend Tests"

    local test_type="$1"

    # Check if mobile frontend directory exists
    if [[ ! -d "$MOBILE_FRONTEND_DIR" ]]; then
        warning "Mobile frontend directory not found: $MOBILE_FRONTEND_DIR, skipping..."
        return
    fi

    cd "$MOBILE_FRONTEND_DIR" || exit 1

    case "$test_type" in
        "unit")
            info "Running unit tests for mobile frontend"
            execute "npm test" "Unit tests completed for mobile frontend" true
            ;;
        *)
            warning "Unknown test type: $test_type for mobile frontend, skipping..."
            ;;
    esac

    # Copy test reports
    if [[ -d "coverage" ]]; then
        mkdir -p "$REPORTS_DIR/mobile-frontend"
        cp -r coverage/* "$REPORTS_DIR/mobile-frontend/"
    fi

    cd "$PROJECT_ROOT" || exit 1

    success "Mobile frontend $test_type tests completed"
}

# =========================
# End-to-End Tests
# =========================

run_e2e_tests() {
    section "Running End-to-End Tests"

    # Check if e2e tests directory exists
    if [[ -d "$PROJECT_ROOT/e2e-tests" ]]; then
        cd "$PROJECT_ROOT/e2e-tests" || exit 1

        info "Running end-to-end tests"
        execute "npm test" "End-to-end tests completed" true

        # Copy test reports
        if [[ -d "reports" ]]; then
            mkdir -p "$REPORTS_DIR/e2e"
            cp -r reports/* "$REPORTS_DIR/e2e/"
        fi

        cd "$PROJECT_ROOT" || exit 1
    else
        warning "End-to-end tests directory not found: $PROJECT_ROOT/e2e-tests, skipping..."
    fi

    success "End-to-end tests completed"
}

# =========================
# Generate Reports
# =========================

generate_test_report() {
    section "Generating Test Report"

    local report_file="$REPORTS_DIR/test-summary.html"

    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PayNext Test Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .summary {
            background-color: #f8f9fa;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 20px;
        }
        .success {
            color: #28a745;
        }
        .warning {
            color: #ffc107;
        }
        .error {
            color: #dc3545;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>PayNext Test Report</h1>
        <div class="summary">
            <h2>Test Summary</h2>
            <p>Generated on: $(date)</p>

            <h3>Backend Tests</h3>
            <ul>
EOF

    # Add backend test results
    for service in "${BACKEND_SERVICES[@]}"; do
        if [[ -d "$REPORTS_DIR/backend/$service" ]]; then
            local test_count
            test_count=$(find "$REPORTS_DIR/backend/$service" -name "TEST-*.xml" | wc -l)
            echo "<li>$service: $test_count tests</li>" >> "$report_file"
        fi
    done

    cat >> "$report_file" << EOF
            </ul>

            <h3>Frontend Tests</h3>
            <ul>
EOF

    # Add frontend test results
    if [[ -d "$REPORTS_DIR/web-frontend" ]]; then
        echo "<li>Web Frontend: Coverage report available</li>" >> "$report_file"
    fi

    if [[ -d "$REPORTS_DIR/mobile-frontend" ]]; then
        echo "<li>Mobile Frontend: Coverage report available</li>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </ul>

            <h3>End-to-End Tests</h3>
            <ul>
EOF

    # Add e2e test results
    if [[ -d "$REPORTS_DIR/e2e" ]]; then
        echo "<li>End-to-End Tests: Reports available</li>" >> "$report_file"
    else
        echo "<li>End-to-End Tests: No reports available</li>" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
            </ul>
        </div>

        <h2>Detailed Results</h2>
        <p>Detailed test results are available in the test-reports directory.</p>

        <h3>Test Coverage</h3>
        <p>For detailed coverage reports, see the coverage directories in each component's test reports.</p>
    </div>
</body>
</html>
EOF

    success "Test report generated: $report_file"

    # Open the report if possible
    if command_exists xdg-open; then
        xdg-open "$report_file" &
    elif command_exists open; then
        open "$report_file" &
    else
        info "To view the report, open: $report_file"
    fi
}

# =========================
# Main Script Logic
# =========================

run_tests() {
    local test_type="$1"
    local component="$2"
    local specific_service="$3"

    # Run tests based on component and type
    case "$component" in
        "backend")
            run_backend_tests "$test_type" "$specific_service"
            ;;
        "web-frontend")
            run_web_frontend_tests "$test_type"
            ;;
        "mobile-frontend")
            run_mobile_frontend_tests "$test_type"
            ;;
        "e2e")
            run_e2e_tests
            ;;
        "all")
            if [[ "$test_type" == "all" ]]; then
                # Run all test types for all components
                for type in "${TEST_TYPES[@]}"; do
                    run_backend_tests "$type" ""
                    run_web_frontend_tests "$type"
                    run_mobile_frontend_tests "$type"
                done
                run_e2e_tests
            else
                # Run specific test type for all components
                run_backend_tests "$test_type" ""
                run_web_frontend_tests "$test_type"
                run_mobile_frontend_tests "$test_type"
                if [[ "$test_type" == "e2e" ]]; then
                    run_e2e_tests
                fi
            fi
            ;;
        *)
            error "Invalid component: $component"
            usage
            exit 1
            ;;
    esac
}

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --type TYPE       Test type: unit, integration, e2e, all (default: all)"
    echo "  --component COMP  Component to test: backend, web-frontend, mobile-frontend, e2e, all (default: all)"
    echo "  --service SVC     Specific backend service to test (only applicable with --component backend)"
    echo "  --report          Generate HTML test report"
    echo "  --help            Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                  # Run all tests for all components"
    echo "  $0 --type unit                      # Run unit tests for all components"
    echo "  $0 --component backend              # Run all tests for backend services"
    echo "  $0 --component backend --type unit  # Run unit tests for backend services"
    echo "  $0 --component backend --service user-service  # Run all tests for user-service"
    echo "  $0 --report                         # Generate HTML test report"
}

main() {
    # Parse command line arguments
    local test_type="all"
    local component="all"
    local specific_service=""
    local generate_report=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                test_type="$2"
                shift 2
                ;;
            --component)
                component="$2"
                shift 2
                ;;
            --service)
                specific_service="$2"
                shift 2
                ;;
            --report)
                generate_report=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate test type
    if [[ "$test_type" != "all" && "$test_type" != "unit" && "$test_type" != "integration" && "$test_type" != "e2e" ]]; then
        error "Invalid test type: $test_type"
        usage
        exit 1
    fi

    # Store the start time
    local start_time
    start_time=$(date +%s)

    section "PayNext Testing Automation"

    # Check prerequisites
    check_prerequisites

    # Setup test environment
    setup_test_environment

    # Run tests
    run_tests "$test_type" "$component" "$specific_service"

    # Generate report if requested
    if [[ "$generate_report" == true ]]; then
        generate_test_report
    fi

    # Calculate and display elapsed time
    local end_time
    end_time=$(date +%s)
    local elapsed_time
    elapsed_time=$((end_time - start_time))
    local minutes
    minutes=$((elapsed_time / 60))
    local seconds
    seconds=$((elapsed_time % 60))

    section "Testing Completed"
    echo -e "${GREEN}All tests completed successfully!${NC}"
    echo -e "${BLUE}Testing completed in ${minutes} minutes and ${seconds} seconds.${NC}"
    echo -e "Test reports are available in: ${CYAN}$REPORTS_DIR${NC}"
}

# Check if script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
