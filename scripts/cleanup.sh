#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧹 Cleaning up AWS resources...${NC}"

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo -e "${RED}Terraform directory not found. Aborting.${NC}"
    exit 1
fi

# Confirm cleanup
echo -e "${YELLOW}⚠️  This will destroy all AWS resources created by Terraform.${NC}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 1
fi

# Navigate to terraform directory
cd terraform

# Destroy infrastructure
echo -e "${YELLOW}Destroying AWS infrastructure...${NC}"
terraform destroy -auto-approve

echo -e "${GREEN}✅ Cleanup completed successfully!${NC}"
echo -e "${YELLOW}All AWS resources have been removed.${NC}"
