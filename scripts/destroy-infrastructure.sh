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

# Default values
AWS_REGION=${AWS_REGION:-"us-east-1"}
PROJECT_NAME=${PROJECT_NAME:-"secure-supply-chain"}

# Function to confirm destruction
confirm_destruction() {
    print_warning "⚠️  WARNING: This will DESTROY ALL AWS resources for project: $PROJECT_NAME"
    print_warning "This includes:"
    print_warning "  - EKS Cluster and Node Groups"
    print_warning "  - VPC, Subnets, and Networking"
    print_warning "  - Load Balancers and Security Groups"
    print_warning "  - IAM Roles and Policies"
    print_warning "  - CloudWatch Log Groups"
    print_warning "  - EBS Volumes and Snapshots"
    print_warning "  - All associated resources"
    echo
    print_warning "This action is IRREVERSIBLE!"
    echo
    read -p "Type 'DESTROY' to confirm: " confirmation
    if [ "$confirmation" != "DESTROY" ]; then
        print_error "Destruction cancelled. You must type 'DESTROY' to proceed."
        exit 1
    fi
    echo
}

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    print_success "AWS credentials verified"
}

# Function to pre-destroy cleanup
pre_destroy_cleanup() {
    print_status "Starting pre-destroy cleanup..."
    
    # Delete any remaining load balancers
    print_status "Deleting Application Load Balancers..."
    aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME')].LoadBalancerArn" --output text | xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {} || print_warning "No load balancers to delete"
    
    # Delete any remaining target groups
    print_status "Deleting Target Groups..."
    aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, '$PROJECT_NAME')].TargetGroupArn" --output text | xargs -I {} aws elbv2 delete-target-group --target-group-arn {} || print_warning "No target groups to delete"
    
    # Delete any remaining security groups (except default)
    print_status "Deleting Security Groups..."
    aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, '$PROJECT_NAME') && GroupName != 'default'].GroupId" --output text | xargs -I {} aws ec2 delete-security-group --group-id {} || print_warning "No security groups to delete"
    
    # Delete any remaining CloudWatch log groups
    print_status "Deleting CloudWatch Log Groups..."
    aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$PROJECT_NAME" --query 'logGroups[].logGroupName' --output text | xargs -I {} aws logs delete-log-group --log-group-name {} || print_warning "No log groups to delete"
    
    print_success "Pre-destroy cleanup completed"
}

# Function to destroy Kubernetes resources
destroy_k8s_resources() {
    print_status "Destroying Kubernetes resources..."
    cd terraform/k8s
    
    if [ -f "main.tf" ]; then
        terraform init -reconfigure
        terraform destroy -auto-approve -input=false || print_warning "No K8s resources to destroy"
    else
        print_warning "No K8s Terraform configuration found"
    fi
    
    cd ../..
    print_success "Kubernetes resources destruction completed"
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying AWS infrastructure..."
    cd terraform/infra
    
    terraform init -reconfigure
    
    # Show current state before destruction
    print_status "Current Terraform state:"
    terraform state list
    
    # Destroy infrastructure
    terraform destroy -auto-approve -input=false -var="aws_region=$AWS_REGION"
    
    cd ../..
    print_success "Infrastructure destruction completed"
}

# Function to post-destroy cleanup
post_destroy_cleanup() {
    print_status "Starting post-destroy cleanup..."
    
    # Delete any remaining EBS volumes
    print_status "Deleting EBS volumes..."
    aws ec2 describe-volumes --query "Volumes[?contains(Tags[?Key=='Name'].Value, '$PROJECT_NAME')].VolumeId" --output text | xargs -I {} aws ec2 delete-volume --volume-id {} || print_warning "No volumes to delete"
    
    # Delete any remaining snapshots
    print_status "Deleting EBS snapshots..."
    aws ec2 describe-snapshots --owner-ids self --query "Snapshots[?contains(Description, '$PROJECT_NAME')].SnapshotId" --output text | xargs -I {} aws ec2 delete-snapshot --snapshot-id {} || print_warning "No snapshots to delete"
    
    # Delete any remaining NAT Gateways
    print_status "Deleting NAT Gateways..."
    aws ec2 describe-nat-gateways --query "NatGateways[?contains(Tags[?Key=='Name'].Value, '$PROJECT_NAME')].NatGatewayId" --output text | xargs -I {} aws ec2 delete-nat-gateway --nat-gateway-id {} || print_warning "No NAT gateways to delete"
    
    # Delete any remaining Internet Gateways
    print_status "Deleting Internet Gateways..."
    aws ec2 describe-internet-gateways --query "InternetGateways[?contains(Tags[?Key=='Name'].Value, '$PROJECT_NAME')].InternetGatewayId" --output text | xargs -I {} aws ec2 detach-internet-gateway --internet-gateway-id {} --vpc-id $(aws ec2 describe-internet-gateways --query "InternetGateways[?contains(Tags[?Key=='Name'].Value, '$PROJECT_NAME')].Attachments[0].VpcId" --output text) && aws ec2 delete-internet-gateway --internet-gateway-id {} || print_warning "No internet gateways to delete"
    
    print_success "Post-destroy cleanup completed"
}

# Function to verify destruction
verify_destruction() {
    print_status "Verifying destruction..."
    
    # Check for remaining EKS clusters
    REMAINING_CLUSTERS=$(aws eks list-clusters --query "clusters[?contains(@, '$PROJECT_NAME')]" --output text)
    if [ -n "$REMAINING_CLUSTERS" ]; then
        print_warning "The following EKS clusters still exist:"
        echo "$REMAINING_CLUSTERS"
    else
        print_success "No EKS clusters found"
    fi
    
    # Check for remaining VPCs
    REMAINING_VPCS=$(aws ec2 describe-vpcs --query "Vpcs[?contains(Tags[?Key=='Name'].Value, '$PROJECT_NAME')].VpcId" --output text)
    if [ -n "$REMAINING_VPCS" ]; then
        print_warning "The following VPCs still exist:"
        echo "$REMAINING_VPCS"
    else
        print_success "No VPCs found"
    fi
    
    # Check for remaining IAM roles
    REMAINING_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, '$PROJECT_NAME')].RoleName" --output text)
    if [ -n "$REMAINING_ROLES" ]; then
        print_warning "The following IAM roles still exist:"
        echo "$REMAINING_ROLES"
    else
        print_success "No IAM roles found"
    fi
    
    print_success "Destruction verification completed!"
}

# Main function
main() {
    print_status "Starting comprehensive infrastructure destruction..."
    print_status "Configuration:"
    print_status "  AWS Region: $AWS_REGION"
    print_status "  Project Name: $PROJECT_NAME"
    echo
    
    # Safety checks
    confirm_destruction
    check_aws_credentials
    
    # Destruction process
    pre_destroy_cleanup
    destroy_k8s_resources
    destroy_infrastructure
    post_destroy_cleanup
    verify_destruction
    
    print_success "🎉 Infrastructure destruction completed successfully!"
    print_warning "Please verify that all resources have been destroyed in the AWS console."
}

# Run main function
main "$@"
