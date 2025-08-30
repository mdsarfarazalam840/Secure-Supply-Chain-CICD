#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


echo -e "${GREEN}🚀 Setting up Secure Supply Chain CI/CD on AWS with Docker Hub${NC}"


# Generate Terraform variables from .env
generate_terraform_vars() {
    echo -e "${YELLOW}Generating Terraform variables...${NC}"
    
    # Get GitHub repository
    GITHUB_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')
    
    cat > terraform/terraform.tfvars << EOF
# Generated from .env file
aws_region = "${AWS_REGION}"
project_name = "${APP_NAME}"
github_repository = "${GITHUB_REPO}"
environment = "${NODE_ENV}"

vpc_cidr = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
EOF
    
    echo -e "${GREEN}✅ Terraform variables generated${NC}"
}


# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ $1 is installed${NC}"
    fi
}

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
check_command aws
check_command terraform
check_command kubectl
check_command docker

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}✅ Loading environment variables from .env${NC}"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}❌ load-env.sh script not found${NC}"
    exit 1
fi

# Configure AWS credentials
configure_aws() {
    echo -e "${YELLOW}Configuring AWS credentials...${NC}"
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${YELLOW}Please configure your AWS credentials:${NC}"
        aws configure
    else
        echo -e "${GREEN}✅ AWS credentials already configured${NC}"
    fi
}

# Update variables
update_variables() {
    echo -e "${YELLOW}Updating Terraform variables...${NC}"
    # Get GitHub repository
    GITHUB_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')
    
    if [ -z "$GITHUB_REPO" ]; then
        echo -e "${YELLOW}Could not detect GitHub repository. Please enter it manually (format: owner/repo):${NC}"
        read -p "GitHub repository: " GITHUB_REPO
    fi
    
    echo -e "${GREEN}✅ Variables updated${NC}"
}

# Deploy infrastructure
deploy_infrastructure() {
    echo -e "${YELLOW}Deploying AWS infrastructure...${NC}"
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the plan
    echo -e "${YELLOW}Applying Terraform plan...${NC}"
    terraform apply tfplan
    
    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    ROLE_ARN=$(terraform output -raw github_actions_role_arn)
    
    cd ..
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo -e "${GREEN}Cluster Name: $CLUSTER_NAME${NC}"
    echo -e "${GREEN}GitHub Actions Role ARN: $ROLE_ARN${NC}"
    
    # Store ROLE_ARN for later use
    export ROLE_ARN
}

# Configure kubectl
configure_kubectl() {
    echo -e "${YELLOW}⚙️ Configuring kubectl...${NC}"
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
    echo -e "${GREEN}✅ kubectl configured${NC}"
}

# Install additional tools
install_tools() {
    echo -e "${YELLOW}Installing additional tools...${NC}"
    # Install envsubst if not available
    if ! command -v envsubst >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing gettext (for envsubst)...${NC}"
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y gettext
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y gettext
        elif command -v brew >/dev/null 2>&1; then
            brew install gettext
        fi
    fi
    echo -e "${GREEN}✅ Tools installed${NC}"
}

# Create GitHub secrets instructions
create_github_secrets() {
    echo -e "${YELLOW}📝 GitHub Secrets Setup Instructions:${NC}"
    echo -e "${GREEN}Please add the following secrets to your GitHub repository:${NC}"
    echo -e "${YELLOW}1. Go to your GitHub repository${NC}"
    echo -e "${YELLOW}2. Navigate to Settings > Secrets and variables > Actions${NC}"
    echo -e "${YELLOW}3. Add the following secrets:${NC}"
    echo -e "${GREEN} - AWS_ROLE_ARN: $ROLE_ARN${NC}"
    echo -e "${GREEN} - DOCKER_USERNAME: Your Docker Hub username${NC}"
    echo -e "${GREEN} - DOCKER_PASSWORD: Your Docker Hub password/token${NC}"
    echo ""
    echo -e "${YELLOW}💡 Note: For DOCKER_PASSWORD, use a Docker Hub access token instead of your password for better security${NC}"
}

# Main execution
main() {
    configure_aws
    generate_terraform_vars  # Add this line
    update_variables
    deploy_infrastructure
    configure_kubectl
    install_tools
    create_github_secrets
    
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${GREEN}1. Add the required secrets to your GitHub repository${NC}"
    echo -e "${GREEN}2. Push your code to trigger the CI/CD pipeline${NC}"
    echo -e "${GREEN}3. Monitor the deployment in GitHub Actions${NC}"
    echo -e "${GREEN}4. Images will be built and pushed to Docker Hub${NC}"
    echo -e "${GREEN}5. Application will be deployed to AWS EKS${NC}"
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
}

# Run main function
main "$@"
