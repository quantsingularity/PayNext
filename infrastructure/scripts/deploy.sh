#!/bin/bash

# PayNext Infrastructure Deployment Script
# This script automates the deployment of PayNext infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
LOG_FILE="/tmp/paynext-deploy-$(date +%Y%m%d-%H%M%S).log"

# Default values
ENVIRONMENT=""
REGION=""
AUTO_APPROVE=false
DESTROY=false
PLAN_ONLY=false
VALIDATE_ONLY=false

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

usage() {
    cat << EOF
PayNext Infrastructure Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Deployment environment (dev, staging, prod)
    -r, --region REGION      AWS region (e.g., us-west-2)
    -a, --auto-approve       Auto-approve Terraform apply
    -d, --destroy           Destroy infrastructure
    -p, --plan-only         Only run terraform plan
    -v, --validate-only     Only validate configuration
    -h, --help              Show this help message

EXAMPLES:
    # Deploy to development environment
    $0 -e dev -r us-west-2

    # Plan deployment to production
    $0 -e prod -r us-west-2 -p

    # Destroy staging environment
    $0 -e staging -r us-west-2 -d

    # Validate configuration only
    $0 -v

EOF
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if required tools are installed
    local tools=("terraform" "aws" "kubectl" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
        fi
    done

    # Check Terraform version
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    local required_version="1.5.0"
    if ! printf '%s\n%s\n' "$required_version" "$tf_version" | sort -V -C; then
        error "Terraform version $tf_version is too old. Required: $required_version or later"
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
    fi

    log "Prerequisites check passed"
}

validate_environment() {
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod"
    fi

    if [[ -z "$REGION" ]]; then
        error "Region is required"
    fi

    log "Environment validation passed: $ENVIRONMENT in $REGION"
}

setup_terraform() {
    log "Setting up Terraform..."

    cd "$TERRAFORM_DIR"

    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init -upgrade

    # Validate configuration
    log "Validating Terraform configuration..."
    terraform validate

    # Format check
    if ! terraform fmt -check=true -diff=true; then
        warn "Terraform files are not properly formatted. Run 'terraform fmt' to fix."
    fi

    log "Terraform setup completed"
}

create_tfvars() {
    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"

    if [[ ! -f "$tfvars_file" ]]; then
        log "Creating terraform.tfvars from example..."
        cp "$TERRAFORM_DIR/terraform.tfvars.example" "$tfvars_file"

        # Update environment and region in tfvars
        sed -i.bak "s/environment = \"dev\"/environment = \"$ENVIRONMENT\"/" "$tfvars_file"
        sed -i.bak "s/aws_region = \"us-west-2\"/aws_region = \"$REGION\"/" "$tfvars_file"
        rm -f "${tfvars_file}.bak"

        warn "terraform.tfvars created from example. Please review and customize before proceeding."
        info "Edit $tfvars_file to match your requirements"

        if [[ "$AUTO_APPROVE" == false ]]; then
            read -p "Press Enter to continue after reviewing terraform.tfvars..."
        fi
    fi
}

run_terraform_plan() {
    log "Running Terraform plan..."

    cd "$TERRAFORM_DIR"

    local plan_file
    plan_file="tfplan-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"

    terraform plan \
        -var="environment=$ENVIRONMENT" \
        -var="region=$REGION" \
        -out="$plan_file" \
        -detailed-exitcode

    local exit_code=$?

    case $exit_code in
        0)
            info "No changes detected"
            ;;
        1)
            error "Terraform plan failed"
            ;;
        2)
            info "Changes detected and plan saved to $plan_file"
            ;;
    esac

    return $exit_code
}

run_terraform_apply() {
    log "Running Terraform apply..."

    cd "$TERRAFORM_DIR"

    local apply_args=()
    apply_args+=("-var=environment=$ENVIRONMENT")
    apply_args+=("-var=region=$REGION")

    if [[ "$AUTO_APPROVE" == true ]]; then
        apply_args+=("-auto-approve")
    fi

    terraform apply "${apply_args[@]}"

    log "Terraform apply completed successfully"
}

run_terraform_destroy() {
    log "Running Terraform destroy..."

    cd "$TERRAFORM_DIR"

    warn "This will destroy all infrastructure in environment: $ENVIRONMENT"

    if [[ "$AUTO_APPROVE" == false ]]; then
        read -p "Are you sure you want to destroy the infrastructure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            info "Destroy cancelled"
            exit 0
        fi
    fi

    local destroy_args=()
    destroy_args+=("-var=environment=$ENVIRONMENT")
    destroy_args+=("-var=region=$REGION")

    if [[ "$AUTO_APPROVE" == true ]]; then
        destroy_args+=("-auto-approve")
    fi

    terraform destroy "${destroy_args[@]}"

    log "Terraform destroy completed successfully"
}

configure_kubectl() {
    log "Configuring kubectl..."

    local cluster_name="paynext-cluster-$ENVIRONMENT"

    # Update kubeconfig
    aws eks update-kubeconfig \
        --region "$REGION" \
        --name "$cluster_name" \
        --alias "$cluster_name"

    # Verify connection
    if kubectl get nodes &> /dev/null; then
        log "kubectl configured successfully"
        kubectl get nodes
    else
        warn "kubectl configuration may have issues. Check EKS cluster status."
    fi
}

post_deployment_checks() {
    log "Running post-deployment checks..."

    cd "$TERRAFORM_DIR"

    # Get outputs
    log "Terraform outputs:"
    terraform output

    # Check EKS cluster if it exists
    local cluster_name="paynext-cluster-$ENVIRONMENT"
    if aws eks describe-cluster --name "$cluster_name" --region "$REGION" &> /dev/null; then
        configure_kubectl
    fi

    # Check RDS cluster
    local db_cluster_id="paynext-cluster-$ENVIRONMENT"
    if aws rds describe-db-clusters --db-cluster-identifier "$db_cluster_id" --region "$REGION" &> /dev/null; then
        log "RDS cluster is available"
    fi

    # Check S3 buckets
    log "S3 buckets created:"
    aws s3 ls | grep "paynext.*$ENVIRONMENT" || true

    log "Post-deployment checks completed"
}

generate_summary() {
    log "Generating deployment summary..."

    cat << EOF

================================================================================
                        PAYNEXT DEPLOYMENT SUMMARY
================================================================================

Environment: $ENVIRONMENT
Region: $REGION
Timestamp: $(date)
Log File: $LOG_FILE

Infrastructure Components:
- VPC with multi-tier subnets
- EKS cluster with managed node groups
- RDS Aurora PostgreSQL cluster
- S3 buckets with encryption and lifecycle policies
- CloudWatch monitoring and alerting
- GuardDuty threat detection
- AWS Config compliance monitoring
- CloudTrail audit logging

Security Features:
- Encryption at rest and in transit
- IAM roles with least privilege
- Security groups and NACLs
- VPC Flow Logs
- WAF protection

Compliance Standards:
- PCI DSS
- GDPR
- SOX

Next Steps:
1. Review the infrastructure in AWS Console
2. Configure application deployments
3. Set up monitoring dashboards
4. Test backup and recovery procedures
5. Configure DNS and SSL certificates

For support, contact: platform-team@yourcompany.com

================================================================================

EOF
}

cleanup() {
    log "Cleaning up temporary files..."
    # Add any cleanup tasks here
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -d|--destroy)
            DESTROY=true
            shift
            ;;
        -p|--plan-only)
            PLAN_ONLY=true
            shift
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    log "Starting PayNext infrastructure deployment..."
    log "Log file: $LOG_FILE"

    # Trap for cleanup
    trap cleanup EXIT

    # Check prerequisites
    check_prerequisites

    # Validate-only mode
    if [[ "$VALIDATE_ONLY" == true ]]; then
        setup_terraform
        log "Validation completed successfully"
        exit 0
    fi

    # Validate inputs
    validate_environment

    # Setup Terraform
    setup_terraform

    # Create tfvars if needed
    create_tfvars

    # Plan-only mode
    if [[ "$PLAN_ONLY" == true ]]; then
        run_terraform_plan
        exit 0
    fi

    # Destroy mode
    if [[ "$DESTROY" == true ]]; then
        run_terraform_destroy
        exit 0
    fi

    # Normal deployment
    run_terraform_plan
    run_terraform_apply
    post_deployment_checks
    generate_summary

    log "PayNext infrastructure deployment completed successfully!"
}

# Validate required parameters
if [[ "$VALIDATE_ONLY" == false && "$PLAN_ONLY" == false ]]; then
    if [[ -z "$ENVIRONMENT" || -z "$REGION" ]]; then
        error "Environment and region are required. Use -h for help."
    fi
fi

# Run main function
main "$@"
