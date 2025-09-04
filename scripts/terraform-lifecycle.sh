#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to cleanup existing resources
cleanup_existing_resources() {
    print_status "Starting cleanup of existing resources..."
    
    # Delete existing CloudWatch log group if it exists
    LOG_GROUP_NAME="/aws/eks/${PROJECT_NAME}-cluster/cluster"
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --query 'logGroups[?logGroupName==`'$LOG_GROUP_NAME'`]' --output text | grep -q "$LOG_GROUP_NAME"; then
        print_warning "Deleting existing CloudWatch log group: $LOG_GROUP_NAME"
        aws logs delete-log-group --log-group-name "$LOG_GROUP_NAME" || print_warning "Failed to delete log group (may not exist)"
    fi
    
    # Note: IAM roles are not deleted during cleanup to avoid breaking existing configurations
    # They will be imported into Terraform state instead
    
    print_success "Cleanup completed"
}

# Function to initialize Terraform
terraform_init() {
    print_status "Initializing Terraform..."
    cd terraform/infra
    
    # Remove existing .terraform directory to ensure clean initialization
    if [ -d ".terraform" ]; then
        print_warning "Removing existing .terraform directory for clean initialization"
        rm -rf .terraform
    fi
    
    # Initialize Terraform
    terraform init -upgrade
    
    print_success "Terraform initialized successfully"
    cd ../..
}

# Function to validate Terraform configuration
terraform_validate() {
    print_status "Validating Terraform configuration..."
    cd terraform/infra
    
    terraform validate
    
    print_success "Terraform configuration is valid"
    cd ../..
}

# Function to plan Terraform changes
terraform_plan() {
    print_status "Planning Terraform changes..."
    cd terraform/infra
    
    terraform plan -input=false -var="aws_region=${AWS_REGION}" -out=tfplan
    
    print_success "Terraform plan completed"
    cd ../..
}

# Function to apply Terraform changes
terraform_apply() {
    print_status "Applying Terraform changes..."
    cd terraform/infra
    
    # Import OIDC Provider if not yet imported
    print_status "Importing OIDC Provider if needed..."
    if ! terraform state show aws_iam_openid_connect_provider.github_actions > /dev/null 2>&1; then
        terraform import aws_iam_openid_connect_provider.github_actions "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" || print_warning "OIDC Provider import failed (may already exist)"
    fi
    
    # Import IAM Role if it exists but not in state
    print_status "Importing IAM Role if needed..."
    ROLE_NAME="${PROJECT_NAME}-github-actions"
    if ! terraform state show aws_iam_role.github_actions > /dev/null 2>&1; then
        if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
            print_warning "IAM Role $ROLE_NAME exists, importing into Terraform state..."
            terraform import aws_iam_role.github_actions "$ROLE_NAME" || print_warning "IAM Role import failed"
        fi
    fi
    
    # Apply the plan
    terraform apply -auto-approve -input=false -var="aws_region=${AWS_REGION}"
    
    print_success "Terraform apply completed"
    cd ../..
}

# Function to get Terraform outputs
get_terraform_outputs() {
    print_status "Getting Terraform outputs..."
    cd terraform/infra
    
    # Export outputs as environment variables
    export CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
    export CLUSTER_CA_CERTIFICATE=$(terraform output -raw cluster_certificate_authority_data)
    export CLUSTER_NAME=$(terraform output -raw cluster_name)
    
    # Print outputs for GitHub Actions
    echo "cluster_endpoint=$CLUSTER_ENDPOINT" >> $GITHUB_OUTPUT
    echo "cluster_ca_certificate=$CLUSTER_CA_CERTIFICATE" >> $GITHUB_OUTPUT
    echo "cluster_name=$CLUSTER_NAME" >> $GITHUB_OUTPUT
    
    print_success "Terraform outputs retrieved"
    print_status "Cluster Name: $CLUSTER_NAME"
    print_status "Cluster Endpoint: $CLUSTER_ENDPOINT"
    
    cd ../..
}

# Function to handle Terraform K8s resources
terraform_k8s_apply() {
    print_status "Applying Terraform K8s resources..."
    cd terraform/k8s
    
    # Initialize Terraform for K8s
    terraform init
    
    # Apply K8s resources
    terraform apply -auto-approve -input=false \
        -var="cluster_endpoint=${CLUSTER_ENDPOINT}" \
        -var="cluster_ca_certificate=${CLUSTER_CA_CERTIFICATE}" \
        -var="cluster_name=${CLUSTER_NAME}"
    
    print_success "Terraform K8s resources applied"
    cd ../..
}

# Main function
main() {
    print_status "Starting Terraform lifecycle management..."
    
    # Set default values if not provided
    export AWS_REGION=${AWS_REGION:-"us-east-1"}
    export PROJECT_NAME=${PROJECT_NAME:-"secure-supply-chain"}
    export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
    
    print_status "Configuration:"
    print_status "  AWS Region: $AWS_REGION"
    print_status "  Project Name: $PROJECT_NAME"
    print_status "  AWS Account ID: $AWS_ACCOUNT_ID"
    
    # Check if we're in GitHub Actions
    if [ "$GITHUB_ACTIONS" = "true" ]; then
        print_status "Running in GitHub Actions environment"
        
        # Only cleanup on push to clouds branch
        if [ "$GITHUB_EVENT_NAME" = "push" ] && [ "$GITHUB_REF" = "refs/heads/clouds" ]; then
            cleanup_existing_resources
        fi
    else
        print_warning "Not running in GitHub Actions - skipping cleanup"
    fi
    
    # Terraform lifecycle
    terraform_init
    terraform_validate
    terraform_plan
    
    # Only apply on push to clouds branch
    if [ "$GITHUB_EVENT_NAME" = "push" ] && [ "$GITHUB_REF" = "refs/heads/clouds" ]; then
        terraform_apply
        get_terraform_outputs
        
        # Apply K8s resources if cluster outputs are available
        if [ -n "$CLUSTER_ENDPOINT" ] && [ -n "$CLUSTER_CA_CERTIFICATE" ] && [ -n "$CLUSTER_NAME" ]; then
            terraform_k8s_apply
        fi
    else
        print_warning "Skipping apply - not on clouds branch or not a push event"
    fi
    
    print_success "Terraform lifecycle completed successfully!"
}

# Run main function
main "$@"
