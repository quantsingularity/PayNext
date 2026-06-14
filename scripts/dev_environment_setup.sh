#!/bin/bash

# =====================================================
#   PayNext - Unified Developer Environment Setup
# =====================================================
# This script automates the complete setup process for the PayNext development environment,
# including infrastructure services, backend services, and frontend applications.

# Exit immediately if a command exits with a non-zero status
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

    echo -e "${CYAN}[EXECUTING]${NC} $cmd"

    if eval "$cmd"; then
        success "$msg"
        return 0
    else
        error "Failed to execute: $cmd"
        return 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a service is running on a specific port
check_service() {
    local service_name="$1"
    local port="$2"
    local max_retries="${3:-30}"
    local retry_interval="${4:-2}"

    info "Checking if $service_name is running on port $port..."

    for ((i=1; i<=max_retries; i++)); do
        if nc -z localhost "$port" >/dev/null 2>&1; then
            success "$service_name is running on port $port"
            return 0
        else
            echo -ne "\r${YELLOW}Waiting for $service_name to start... ($i/$max_retries)${NC}"
            sleep "$retry_interval"
        fi
    done

    echo ""
    error "$service_name failed to start on port $port after $((max_retries * retry_interval)) seconds"
    return 1
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

    # Check Docker
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        success "Docker $docker_version is installed"
    else
        error "Docker is not installed. Please install Docker"
        exit 1
    fi

    # Check Docker Compose
    if command_exists docker-compose; then
        local compose_version
        compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
        success "Docker Compose $compose_version is installed"
    else
        error "Docker Compose is not installed. Please install Docker Compose"
        exit 1
    fi

    # Check kubectl (optional)
    if command_exists kubectl; then
        local kubectl_version
        kubectl_version=$(kubectl version --client --short | awk '{print $3}')
        success "kubectl $kubectl_version is installed"
    else
        warning "kubectl is not installed. It's optional but recommended for Kubernetes deployments"
    fi

    # Check netcat for port checking
    if ! command_exists nc; then
        warning "netcat (nc) is not installed. It's used for service health checks"
        if [[ "$os" == "linux" ]]; then
            info "You can install it with: sudo apt-get install netcat"
        elif [[ "$os" == "macos" ]]; then
            info "You can install it with: brew install netcat"
        elif [[ "$os" == "windows" ]]; then
            info "For Windows, you can use nmap instead or install netcat via WSL"
        fi
    fi

    success "Prerequisites check completed"
}

# =========================
# Environment Setup
# =========================

setup_environment_variables() {
    section "Setting Up Environment Variables"

    # Check if .env file exists
    if [[ -f .env ]]; then
        info "Found .env file, loading environment variables"
        # shellcheck disable=SC1091
        source .env
    else
        info "Creating default .env file"
        cat > .env << EOF
# PayNext Environment Variables
MYSQL_ROOT_PASSWORD=paynext
MYSQL_DATABASE=paynext
MYSQL_USER=paynext
MYSQL_PASSWORD=paynext

# Service Ports
EUREKA_PORT=8761
API_GATEWAY_PORT=8080
USER_SERVICE_PORT=8081
PAYMENT_SERVICE_PORT=8082
TRANSACTION_SERVICE_PORT=8083
NOTIFICATION_SERVICE_PORT=8084
REPORTING_SERVICE_PORT=8085

# Frontend Ports
WEB_FRONTEND_PORT=3000
MOBILE_FRONTEND_PORT=8100

# Infrastructure
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
REDIS_PORT=6379
MYSQL_PORT=3306
MONGODB_PORT=27017

# Monitoring
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
ELASTICSEARCH_PORT=9200
KIBANA_PORT=5601
EOF
        success "Created default .env file"
    fi

    # Load environment variables
    # shellcheck disable=SC1091
    source .env

    success "Environment variables set up successfully"
}

# =========================
# Infrastructure Setup
# =========================

start_infrastructure_services() {
    section "Starting Infrastructure Services"

    info "Starting MySQL, RabbitMQ, Redis, and MongoDB with Docker Compose"

    # Check if docker-compose.yml exists for infrastructure
    if [[ ! -f docker-compose.yml ]]; then
        info "Creating docker-compose.yml for infrastructure services"
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: paynext-mysql
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    ports:
      - "\${MYSQL_PORT}:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p\${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3-management
    container_name: paynext-rabbitmq
    ports:
      - "\${RABBITMQ_PORT}:5672"
      - "\${RABBITMQ_MANAGEMENT_PORT}:15672"
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmqctl", "status"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:6
    container_name: paynext-redis
    ports:
      - "\${REDIS_PORT}:6379"
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  mongodb:
    image: mongo:5
    container_name: paynext-mongodb
    ports:
      - "\${MONGODB_PORT}:27017"
    volumes:
      - mongodb-data:/data/db
    healthcheck:
      test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysql-data:
  rabbitmq-data:
  redis-data:
  mongodb-data:
EOF
        success "Created docker-compose.yml for infrastructure services"
    fi

    # Start infrastructure services
    execute "docker-compose up -d mysql rabbitmq redis mongodb" "Infrastructure services started successfully"

    # Wait for services to be ready
    info "Waiting for infrastructure services to be ready..."
    sleep 10

    # Check if services are running
    check_service "MySQL" "${MYSQL_PORT}"
    check_service "RabbitMQ" "${RABBITMQ_PORT}"
    check_service "Redis" "${REDIS_PORT}"
    check_service "MongoDB" "${MONGODB_PORT}"

    success "All infrastructure services are running"
}

# =========================
# Backend Setup
# =========================

build_backend_services() {
    section "Building Backend Services"

    local backend_dir="backend"

    # Check if backend directory exists
    if [[ ! -d "$backend_dir" ]]; then
        error "Backend directory not found: $backend_dir"
        exit 1
    fi

    # Build backend services
    info "Building backend services with Maven"
    cd "$backend_dir" || exit 1

    # Use the existing Maven wrapper if available
    if [[ -f "mvnw" ]]; then
        execute "./mvnw clean package -DskipTests" "Backend services built successfully"
    else
        execute "mvn clean package -DskipTests" "Backend services built successfully"
    fi

    cd - || exit 1
}

start_backend_services() {
    section "Starting Backend Services"

    local backend_dir="backend"
    local logs_dir="$backend_dir/logs"
    local pids_dir="$backend_dir/pids"

    # Create logs and pids directories if they don't exist
    mkdir -p "$logs_dir"
    mkdir -p "$pids_dir"

    # Define services and their dependencies
    local services=(
        "eureka-server"
        "config-server"
        "api-gateway"
        "user-service"
        "payment-service"
        "transaction-service"
        "notification-service"
        "reporting-service"
    )

    # Define service ports
    declare -A service_ports=(
        ["eureka-server"]="${EUREKA_PORT}"
        ["config-server"]="8888"
        ["api-gateway"]="${API_GATEWAY_PORT}"
        ["user-service"]="${USER_SERVICE_PORT}"
        ["payment-service"]="${PAYMENT_SERVICE_PORT}"
        ["transaction-service"]="${TRANSACTION_SERVICE_PORT}"
        ["notification-service"]="${NOTIFICATION_SERVICE_PORT}"
        ["reporting-service"]="${REPORTING_SERVICE_PORT}"
    )

    # Start services in order
    for service in "${services[@]}"; do
        local service_dir="$backend_dir/$service"
        local jar_file="$service_dir/target/$service.jar"
        local log_file="$logs_dir/$service.log"
        local pid_file="$pids_dir/$service.pid"
        local port="${service_ports[$service]}"

        # Check if service directory exists
        if [[ ! -d "$service_dir" ]]; then
            warning "Service directory not found: $service_dir, skipping..."
            continue
        fi

        # Check if JAR file exists
        if [[ ! -f "$jar_file" ]]; then
            warning "JAR file not found: $jar_file, skipping..."
            continue
        fi

        # Check if service is already running
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file")
            if ps -p "$pid" > /dev/null 2>&1; then
                info "Service $service is already running with PID $pid"
                continue
            else
                info "Removing stale PID file for $service"
                rm -f "$pid_file"
            fi
        fi

        info "Starting $service on port $port"

        # Start the service
        java -jar "$jar_file" --server.port="$port" > "$log_file" 2>&1 &
        local pid=$!
        echo "$pid" > "$pid_file"

        # Wait for service to start
        check_service "$service" "$port"
    done

    success "All backend services started successfully"
}

# =========================
# Frontend Setup
# =========================

build_and_start_web_frontend() {
    section "Building and Starting Web Frontend"

    local frontend_dir="web-frontend"

    # Check if frontend directory exists
    if [[ ! -d "$frontend_dir" ]]; then
        error "Web frontend directory not found: $frontend_dir"
        exit 1
    fi

    # Install dependencies and build
    cd "$frontend_dir" || exit 1

    info "Installing web frontend dependencies"
    execute "npm install" "Web frontend dependencies installed successfully"

    info "Starting web frontend development server"
    execute "npm start &" "Web frontend started successfully"

    # Wait for frontend to start
    check_service "Web Frontend" "${WEB_FRONTEND_PORT}"

    cd - || exit 1
}

build_and_start_mobile_frontend() {
    section "Building Mobile Frontend"

    local mobile_dir="mobile-frontend"

    # Check if mobile directory exists
    if [[ ! -d "$mobile_dir" ]]; then
        warning "Mobile frontend directory not found: $mobile_dir, skipping..."
        return
    fi

    # Install dependencies
    cd "$mobile_dir" || exit 1

    info "Installing mobile frontend dependencies"
    execute "npm install" "Mobile frontend dependencies installed successfully"

    info "Mobile frontend is ready for development"
    info "To run on Android: npx react-native run-android"
    info "To run on iOS: npx react-native run-ios"

    cd - || exit 1
}

# =========================
# Verification
# =========================

verify_environment() {
    section "Verifying Development Environment"

    # Check infrastructure services
    info "Checking infrastructure services..."
    check_service "MySQL" "${MYSQL_PORT}" 5 1
    check_service "RabbitMQ" "${RABBITMQ_PORT}" 5 1
    check_service "Redis" "${REDIS_PORT}" 5 1
    check_service "MongoDB" "${MONGODB_PORT}" 5 1

    # Check backend services
    info "Checking backend services..."
    check_service "Eureka Server" "${EUREKA_PORT}" 5 1
    check_service "API Gateway" "${API_GATEWAY_PORT}" 5 1

    # Check frontend
    info "Checking web frontend..."
    check_service "Web Frontend" "${WEB_FRONTEND_PORT}" 5 1

    success "Development environment verification completed"

    # Print access URLs
    section "Access URLs"
    echo -e "${GREEN}Web Dashboard:${NC} http://localhost:${WEB_FRONTEND_PORT}"
    echo -e "${GREEN}API Gateway:${NC} http://localhost:${API_GATEWAY_PORT}"
    echo -e "${GREEN}Eureka Server:${NC} http://localhost:${EUREKA_PORT}"
    echo -e "${GREEN}RabbitMQ Management:${NC} http://localhost:${RABBITMQ_MANAGEMENT_PORT}"

    section "Development Environment Setup Complete"
    echo -e "${GREEN}PayNext development environment has been successfully set up!${NC}"
    echo -e "Use ${CYAN}./stop_environment.sh${NC} to stop the environment when you're done."
}

# =========================
# Main Script Logic
# =========================

main() {
    section "PayNext Development Environment Setup"

    # Store the start time
    local start_time
    start_time=$(date +%s)

    # Check prerequisites
    check_prerequisites

    # Setup environment variables
    setup_environment_variables

    # Start infrastructure services
    start_infrastructure_services

    # Build and start backend services
    build_backend_services
    start_backend_services

    # Build and start frontend
    build_and_start_web_frontend
    build_and_start_mobile_frontend

    # Verify environment
    verify_environment

    # Calculate and display elapsed time
    local end_time
    end_time=$(date +%s)
    local elapsed_time
    elapsed_time=$((end_time - start_time))
    local minutes
    minutes=$((elapsed_time / 60))
    local seconds
    seconds=$((elapsed_time % 60))

    echo -e "\n${BLUE}Setup completed in ${minutes} minutes and ${seconds} seconds.${NC}"
}

# Execute main function
main "$@"
