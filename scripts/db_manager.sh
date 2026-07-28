#!/bin/bash

# =====================================================
#   PayNext - Development Database Management Script
# =====================================================
# This script automates database management tasks for the PayNext development environment,
# including initialization, migration, seeding, backup, and restoration.

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

# =========================
# Configuration
# =========================

# Load environment variables
load_env_vars() {
    if [[ -f .env ]]; then
        # shellcheck disable=SC1091
        source .env
    else
        # Default values
        export MYSQL_ROOT_PASSWORD="paynext"
        export MYSQL_DATABASE="paynext"
        export MYSQL_USER="paynext"
        export MYSQL_PASSWORD="paynext"
        export MYSQL_PORT="3306"
        export MONGODB_PORT="27017"
    fi
}

# =========================
# MySQL Database Management
# =========================

# Initialize MySQL database
mysql_init() {
    section "Initializing MySQL Database"

    info "Checking MySQL connection..."
    if ! command_exists mysql; then
        error "MySQL client not found. Please install MySQL client."
        return 1
    fi

    # Check if MySQL is running
    if ! check_service "MySQL" "${MYSQL_PORT}" 5 1; then
        error "MySQL is not running. Please start MySQL first."
        return 1
    fi

    # Create database if it doesn't exist
    info "Creating database ${MYSQL_DATABASE} if it doesn't exist..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e 'CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};'" "Database ${MYSQL_DATABASE} created or already exists"

    # Create user if it doesn't exist
    info "Creating user ${MYSQL_USER} if it doesn't exist..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e \"CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';\"" "User ${MYSQL_USER} created or already exists"

    # Grant privileges
    info "Granting privileges to ${MYSQL_USER}..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e \"GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';\"" "Privileges granted to ${MYSQL_USER}"

    # Flush privileges
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e 'FLUSH PRIVILEGES;'" "Privileges flushed"

    success "MySQL database initialized successfully"
}

# Run MySQL migrations
mysql_migrate() {
    section "Running MySQL Migrations"

    local migrations_dir="$1"

    if [[ -z "$migrations_dir" ]]; then
        migrations_dir="./backend/db/migrations"
    fi

    if [[ ! -d "$migrations_dir" ]]; then
        error "Migrations directory not found: $migrations_dir"
        return 1
    fi

    info "Running migrations from $migrations_dir..."

    # Find all SQL files in the migrations directory
    local migration_files=()
    while IFS= read -r -d '' file; do
        migration_files+=("$file")
    done < <(find "$migrations_dir" -name "*.sql" -type f -print0 | sort -z)

    if [[ ${#migration_files[@]} -eq 0 ]]; then
        warning "No migration files found in $migrations_dir"
        return 0
    fi

    # Run each migration file
    for file in "${migration_files[@]}"; do
        local filename
        filename=$(basename "$file")
        info "Running migration: $filename"
        execute "mysql -h localhost -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < \"$file\"" "Migration $filename completed" true
    done

    success "MySQL migrations completed successfully"
}

# Seed MySQL database with test data
mysql_seed() {
    section "Seeding MySQL Database"

    local seed_file="$1"

    if [[ -z "$seed_file" ]]; then
        seed_file="./backend/db/seeds/seed.sql"
    fi

    if [[ ! -f "$seed_file" ]]; then
        error "Seed file not found: $seed_file"
        return 1
    fi

    info "Seeding database with $seed_file..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < \"$seed_file\"" "Database seeded successfully"

    success "MySQL database seeded successfully"
}

# Backup MySQL database
mysql_backup() {
    section "Backing Up MySQL Database"

    local backup_dir="$1"

    if [[ -z "$backup_dir" ]]; then
        backup_dir="./backups/mysql"
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"

    # Generate backup filename with timestamp
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/${MYSQL_DATABASE}_${timestamp}.sql"

    info "Backing up database ${MYSQL_DATABASE} to $backup_file..."
    execute "mysqldump -h localhost -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} > \"$backup_file\"" "Database backup created: $backup_file"

    # Compress the backup
    info "Compressing backup..."
    execute "gzip \"$backup_file\"" "Backup compressed: $backup_file.gz"

    success "MySQL database backup completed successfully"
    echo -e "Backup file: ${CYAN}$backup_file.gz${NC}"
}

# Restore MySQL database from backup
mysql_restore() {
    section "Restoring MySQL Database"

    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        error "No backup file specified"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    info "Restoring database ${MYSQL_DATABASE} from $backup_file..."

    # Check if the file is compressed
    if [[ "$backup_file" == *.gz ]]; then
        execute "gunzip -c \"$backup_file\" | mysql -h localhost -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}" "Database restored successfully"
    else
        execute "mysql -h localhost -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < \"$backup_file\"" "Database restored successfully"
    fi

    success "MySQL database restored successfully"
}

# Reset MySQL database (drop and recreate)
mysql_reset() {
    section "Resetting MySQL Database"

    info "This will drop and recreate the database ${MYSQL_DATABASE}"
    read -p "Are you sure you want to continue? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Database reset cancelled"
        return 0
    fi

    # Drop database
    info "Dropping database ${MYSQL_DATABASE}..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e 'DROP DATABASE IF EXISTS ${MYSQL_DATABASE};'" "Database ${MYSQL_DATABASE} dropped"

    # Recreate database
    info "Recreating database ${MYSQL_DATABASE}..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e 'CREATE DATABASE ${MYSQL_DATABASE};'" "Database ${MYSQL_DATABASE} created"

    # Grant privileges
    info "Granting privileges to ${MYSQL_USER}..."
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e \"GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';\"" "Privileges granted to ${MYSQL_USER}"

    # Flush privileges
    execute "mysql -h localhost -P ${MYSQL_PORT} -u root -p${MYSQL_ROOT_PASSWORD} -e 'FLUSH PRIVILEGES;'" "Privileges flushed"

    success "MySQL database reset successfully"

    # Ask if user wants to run migrations
    read -p "Do you want to run migrations? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mysql_migrate
    fi

    # Ask if user wants to seed the database
    read -p "Do you want to seed the database? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mysql_seed
    fi
}

# =========================
# MongoDB Database Management
# =========================

# Initialize MongoDB database
mongodb_init() {
    section "Initializing MongoDB Database"

    info "Checking MongoDB connection..."
    if ! command_exists mongosh; then
        error "MongoDB shell not found. Please install MongoDB shell."
        return 1
    fi

    # Check if MongoDB is running
    if ! check_service "MongoDB" "${MONGODB_PORT}" 5 1; then
        error "MongoDB is not running. Please start MongoDB first."
        return 1
    fi

    # Create database and user
    info "Creating database and user..."
    execute "mongosh --port ${MONGODB_PORT} --eval 'use ${MYSQL_DATABASE}; db.createUser({user: \"${MYSQL_USER}\", pwd: \"${MYSQL_PASSWORD}\", roles: [{role: \"readWrite\", db: \"${MYSQL_DATABASE}\"}]})'" "Database and user created" true

    success "MongoDB database initialized successfully"
}

# Seed MongoDB database with test data
mongodb_seed() {
    section "Seeding MongoDB Database"

    local seed_file="$1"

    if [[ -z "$seed_file" ]]; then
        seed_file="./backend/db/seeds/mongo-seed.js"
    fi

    if [[ ! -f "$seed_file" ]]; then
        error "Seed file not found: $seed_file"
        return 1
    fi

    info "Seeding database with $seed_file..."
    execute "mongosh --port ${MONGODB_PORT} ${MYSQL_DATABASE} \"$seed_file\"" "Database seeded successfully"

    success "MongoDB database seeded successfully"
}

# Backup MongoDB database
mongodb_backup() {
    section "Backing Up MongoDB Database"

    local backup_dir="$1"

    if [[ -z "$backup_dir" ]]; then
        backup_dir="./backups/mongodb"
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"

    # Generate backup filename with timestamp
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/${MYSQL_DATABASE}_${timestamp}"

    info "Backing up database ${MYSQL_DATABASE} to $backup_file..."
    execute "mongodump --port ${MONGODB_PORT} --db ${MYSQL_DATABASE} --out \"$backup_file\"" "Database backup created: $backup_file"

    # Compress the backup
    info "Compressing backup..."
    # shellcheck disable=SC2086  # eval-built command with intentional inner quoting; paths are script-controlled
    execute "tar -czf \"$backup_file.tar.gz\" -C \"$backup_dir\" \"$(basename \"$backup_file\")\"" "Backup compressed: $backup_file.tar.gz"

    # Remove the uncompressed backup
    execute "rm -rf \"$backup_file\"" "Uncompressed backup removed"

    success "MongoDB database backup completed successfully"
    echo -e "Backup file: ${CYAN}$backup_file.tar.gz${NC}"
}

# Restore MongoDB database from backup
mongodb_restore() {
    section "Restoring MongoDB Database"

    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        error "No backup file specified"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    info "Restoring database ${MYSQL_DATABASE} from $backup_file..."

    # Check if the file is compressed
    if [[ "$backup_file" == *.tar.gz ]]; then
        local temp_dir
        temp_dir="/tmp/mongodb_restore_$(date +%s)"
        mkdir -p "$temp_dir"

        info "Extracting backup..."
        execute "tar -xzf \"$backup_file\" -C \"$temp_dir\"" "Backup extracted"

        info "Restoring database..."
        execute "mongorestore --port ${MONGODB_PORT} --db ${MYSQL_DATABASE} \"$temp_dir/${MYSQL_DATABASE}\"" "Database restored successfully"

        info "Cleaning up..."
        execute "rm -rf \"$temp_dir\"" "Temporary files removed"
    else
        execute "mongorestore --port ${MONGODB_PORT} --db ${MYSQL_DATABASE} \"$backup_file\"" "Database restored successfully"
    fi

    success "MongoDB database restored successfully"
}

# Reset MongoDB database (drop and recreate)
mongodb_reset() {
    section "Resetting MongoDB Database"

    info "This will drop and recreate the database ${MYSQL_DATABASE}"
    read -p "Are you sure you want to continue? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Database reset cancelled"
        return 0
    fi

    # Drop database
    info "Dropping database ${MYSQL_DATABASE}..."
    execute "mongosh --port ${MONGODB_PORT} --eval 'use ${MYSQL_DATABASE}; db.dropDatabase()'" "Database ${MYSQL_DATABASE} dropped"

    # Recreate database and user
    info "Recreating database and user..."
    execute "mongosh --port ${MONGODB_PORT} --eval 'use ${MYSQL_DATABASE}; db.createUser({user: \"${MYSQL_USER}\", pwd: \"${MYSQL_PASSWORD}\", roles: [{role: \"readWrite\", db: \"${MYSQL_DATABASE}\"}]})'" "Database and user created" true

    success "MongoDB database reset successfully"

    # Ask if user wants to seed the database
    read -p "Do you want to seed the database? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mongodb_seed
    fi
}

# =========================
# Usage
# =========================

usage() {
    echo "Usage: $0 [options] <command>"
    echo ""
    echo "Commands:"
    echo "  mysql-init                Initialize MySQL database"
    echo "  mysql-migrate [dir]       Run MySQL migrations (optional: migrations directory)"
    echo "  mysql-seed [file]         Seed MySQL database with test data (optional: seed file)"
    echo "  mysql-backup [dir]        Backup MySQL database (optional: backup directory)"
    echo "  mysql-restore <file>      Restore MySQL database from backup"
    echo "  mysql-reset               Reset MySQL database (drop and recreate)"
    echo ""
    echo "  mongodb-init              Initialize MongoDB database"
    echo "  mongodb-seed [file]       Seed MongoDB database with test data (optional: seed file)"
    echo "  mongodb-backup [dir]      Backup MongoDB database (optional: backup directory)"
    echo "  mongodb-restore <file>    Restore MongoDB database from backup"
    echo "  mongodb-reset             Reset MongoDB database (drop and recreate)"
    echo ""
    echo "  init-all                  Initialize both MySQL and MongoDB databases"
    echo "  seed-all                  Seed both MySQL and MongoDB databases"
    echo "  backup-all [dir]          Backup both MySQL and MongoDB databases (optional: backup directory)"
    echo "  reset-all                 Reset both MySQL and MongoDB databases"
    echo ""
    echo "Options:"
    echo "  --help                    Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 mysql-init             # Initialize MySQL database"
    echo "  $0 mysql-backup           # Backup MySQL database to default location"
    echo "  $0 mysql-backup ./my-backups  # Backup MySQL database to custom location"
    echo "  $0 mysql-restore ./backups/mysql/paynext_20250522_120000.sql.gz  # Restore from backup"
    echo "  $0 init-all               # Initialize both MySQL and MongoDB databases"
}

# =========================
# Main Script Logic
# =========================

main() {
    # Check if no arguments provided
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    # Parse command line arguments
    local command="$1"
    shift

    # Load environment variables
    load_env_vars

    # Process commands
    case "$command" in
        mysql-init)
            mysql_init
            ;;
        mysql-migrate)
            mysql_migrate "$1"
            ;;
        mysql-seed)
            mysql_seed "$1"
            ;;
        mysql-backup)
            mysql_backup "$1"
            ;;
        mysql-restore)
            if [[ -z "$1" ]]; then
                error "No backup file specified"
                usage
                exit 1
            fi
            mysql_restore "$1"
            ;;
        mysql-reset)
            mysql_reset
            ;;
        mongodb-init)
            mongodb_init
            ;;
        mongodb-seed)
            mongodb_seed "$1"
            ;;
        mongodb-backup)
            mongodb_backup "$1"
            ;;
        mongodb-restore)
            if [[ -z "$1" ]]; then
                error "No backup file specified"
                usage
                exit 1
            fi
            mongodb_restore "$1"
            ;;
        mongodb-reset)
            mongodb_reset
            ;;
        init-all)
            mysql_init
            mongodb_init
            ;;
        seed-all)
            mysql_seed "$1"
            mongodb_seed "$1"
            ;;
        backup-all)
            mysql_backup "$1"
            mongodb_backup "$1"
            ;;
        reset-all)
            mysql_reset
            mongodb_reset
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
