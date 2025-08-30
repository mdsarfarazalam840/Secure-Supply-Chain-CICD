#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Setting up Secure Supply Chain CI/CD on AWS with Docker Hub${NC}"

# Check if required tools are installed
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}" >&2; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }
    
    echo -e "${GREEN}✅ All requirements met${NC}"
}

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
    
    # Update terraform/variables.tf
    sed -i "s/your-username\/secure-supply-chain-cicd/$GITHUB_REPO/g" terraform/variables.tf
    
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
}

# Configure kubectl
configure_kubectl() {
    echo -e "${YELLOW}Configuring kubectl...${NC}"
    
    cd terraform
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    AWS_REGION=$(terraform output -raw cluster_endpoint | grep -o 'us-[a-z0-9-]*' | head -1)
    cd ..
    
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
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
    echo -e "${GREEN}   - AWS_ROLE_ARN: $ROLE_ARN${NC}"
    echo -e "${GREEN}   - DOCKER_USERNAME: Your Docker Hub username${NC}"
    echo -e "${GREEN}   - DOCKER_PASSWORD: Your Docker Hub password/token${NC}"
    echo ""
    echo -e "${YELLOW}📋 Copy these commands to add the secrets:${NC}"
    echo -e "${GREEN}gh secret set AWS_ROLE_ARN --body \"$ROLE_ARN\"${NC}"
    echo -e "${GREEN}gh secret set DOCKER_USERNAME --body \"your-docker-username\"${NC}"
    echo -e "${GREEN}gh secret set DOCKER_PASSWORD --body \"your-docker-password\"${NC}"
    echo ""
    echo -e "${YELLOW}💡 Note: For DOCKER_PASSWORD, use a Docker Hub access token instead of your password for better security${NC}"
}

# Main execution
main() {
    check_requirements
    configure_aws
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
}

# Run main function
main "$@"
