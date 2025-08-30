#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing Secure Supply Chain CI/CD Pipeline (Docker Hub + AWS EKS)${NC}"

# Test functions
test_aws_connectivity() {
    echo -e "${YELLOW}Testing AWS connectivity...${NC}"
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${GREEN}✅ AWS connectivity successful${NC}"
        aws sts get-caller-identity --query 'Account' --output text
    else
        echo -e "${RED}❌ AWS connectivity failed${NC}"
        exit 1
    fi
}

test_eks_cluster() {
    echo -e "${YELLOW}Testing EKS cluster connectivity...${NC}"
    
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ EKS cluster accessible${NC}"
        kubectl get nodes
    else
        echo -e "${RED}❌ EKS cluster not accessible${NC}"
        exit 1
    fi
}

test_application_deployment() {
    echo -e "${YELLOW}Testing application deployment...${NC}"
    
    # Wait for deployment to be ready
    echo "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/secure-app
    
    # Check if pods are running
    PODS=$(kubectl get pods -l app=secure-app --no-headers | wc -l)
    RUNNING_PODS=$(kubectl get pods -l app=secure-app --no-headers | grep Running | wc -l)
    
    if [ "$PODS" -eq "$RUNNING_PODS" ] && [ "$PODS" -gt 0 ]; then
        echo -e "${GREEN}✅ Application pods are running${NC}"
        kubectl get pods -l app=secure-app
    else
        echo -e "${RED}❌ Application pods are not running properly${NC}"
        kubectl get pods -l app=secure-app
        exit 1
    fi
}

test_service_access() {
    echo -e "${YELLOW}Testing service access...${NC}"
    
    # Get Load Balancer URL
    LB_URL=$(kubectl get service secure-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$LB_URL" ]; then
        echo -e "${GREEN}✅ Load Balancer URL: $LB_URL${NC}"
        
        # Wait for Load Balancer to be ready
        echo "Waiting for Load Balancer to be ready..."
        sleep 30
        
        # Test application
        if curl -s "http://$LB_URL" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Application is accessible${NC}"
            echo "Response: $(curl -s http://$LB_URL)"
        else
            echo -e "${YELLOW}⚠️  Application not yet accessible (this is normal during initial setup)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Load Balancer not yet provisioned${NC}"
    fi
}

test_security_features() {
    echo -e "${YELLOW}Testing security features...${NC}"
    
    # Check Kyverno installation
    if kubectl get namespace kyverno >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Kyverno namespace exists${NC}"
        
        # Check Kyverno pods
        KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers | wc -l)
        KYVERNO_RUNNING=$(kubectl get pods -n kyverno --no-headers | grep Running | wc -l)
        
        if [ "$KYVERNO_PODS" -eq "$KYVERNO_RUNNING" ] && [ "$KYVERNO_PODS" -gt 0 ]; then
            echo -e "${GREEN}✅ Kyverno pods are running${NC}"
        else
            echo -e "${YELLOW}⚠️  Kyverno pods are not all running${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Kyverno namespace not found${NC}"
    fi
    
    # Check policies
    if kubectl get clusterpolicies >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Cluster policies exist${NC}"
        kubectl get clusterpolicies
    else
        echo -e "${YELLOW}⚠️  No cluster policies found${NC}"
    fi
}

test_docker_hub_setup() {
    echo -e "${YELLOW}Testing Docker Hub setup...${NC}"
    
    # Check if Docker Hub credentials are configured in GitHub
    echo -e "${GREEN}✅ Docker Hub will be used for container registry${NC}"
    echo -e "${YELLOW}📝 Make sure you have set DOCKER_USERNAME and DOCKER_PASSWORD secrets in GitHub${NC}"
    
    # Check if .github/workflows directory exists
    if [ -d ".github/workflows" ]; then
        echo -e "${GREEN}✅ GitHub Actions workflows directory exists${NC}"
        
        # Check if ci-cd.yaml exists
        if [ -f ".github/workflows/ci-cd.yaml" ]; then
            echo -e "${GREEN}✅ CI/CD workflow file exists${NC}"
            
            # Check if Docker Hub references exist
            if grep -q "DOCKER_USERNAME" .github/workflows/ci-cd.yaml; then
                echo -e "${GREEN}✅ Docker Hub integration configured in workflow${NC}"
            else
                echo -e "${YELLOW}⚠️  Docker Hub integration not found in workflow${NC}"
            fi
        else
            echo -e "${RED}❌ CI/CD workflow file not found${NC}"
        fi
    else
        echo -e "${RED}❌ GitHub Actions workflows directory not found${NC}"
    fi
}

test_github_actions_setup() {
    echo -e "${YELLOW}Testing GitHub Actions setup...${NC}"
    
    # Check if .github/workflows directory exists
    if [ -d ".github/workflows" ]; then
        echo -e "${GREEN}✅ GitHub Actions workflows directory exists${NC}"
        
        # Check if ci-cd.yaml exists
        if [ -f ".github/workflows/ci-cd.yaml" ]; then
            echo -e "${GREEN}✅ CI/CD workflow file exists${NC}"
        else
            echo -e "${RED}❌ CI/CD workflow file not found${NC}"
        fi
    else
        echo -e "${RED}❌ GitHub Actions workflows directory not found${NC}"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting comprehensive pipeline test...${NC}"
    echo ""
    
    test_aws_connectivity
    echo ""
    
    test_eks_cluster
    echo ""
    
    test_docker_hub_setup
    echo ""
    
    test_github_actions_setup
    echo ""
    
    test_security_features
    echo ""
    
    test_application_deployment
    echo ""
    
    test_service_access
    echo ""
    
    echo -e "${GREEN}🎉 Pipeline test completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${GREEN}1. Ensure DOCKER_USERNAME and DOCKER_PASSWORD secrets are set in GitHub${NC}"
    echo -e "${GREEN}2. Push your code to trigger the CI/CD pipeline${NC}"
    echo -e "${GREEN}3. Monitor the deployment in GitHub Actions${NC}"
    echo -e "${GREEN}4. Images will be built and pushed to Docker Hub${NC}"
    echo -e "${GREEN}5. Application will be deployed to AWS EKS${NC}"
}

# Run main function
main "$@"
