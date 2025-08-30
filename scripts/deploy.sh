#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Deploying to Kubernetes with environment variables${NC}"

# Load environment variables
source scripts/load-env.sh

# Set IMAGE_URI if not provided
if [ -z "$IMAGE_URI" ]; then
    IMAGE_URI="${DOCKER_USERNAME}/${APP_NAME}:latest"
    echo -e "${YELLOW}Using default image: $IMAGE_URI${NC}"
fi

# Export variables for envsubst
export IMAGE_URI
export APP_NAME
export SERVICE_NAME
export DEPLOYMENT_NAME
export NODE_ENV
export NAMESPACE

echo -e "${YELLOW}Deploying with the following configuration:${NC}"
echo -e "${GREEN}Image: $IMAGE_URI${NC}"
echo -e "${GREEN}App Name: $APP_NAME${NC}"
echo -e "${GREEN}Service: $SERVICE_NAME${NC}"
echo -e "${GREEN}Deployment: $DEPLOYMENT_NAME${NC}"
echo -e "${GREEN}Environment: $NODE_ENV${NC}"
echo -e "${GREEN}Namespace: $NAMESPACE${NC}"

# Apply Kubernetes manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply policy (if exists)
if [ -f "k8s/policy.yaml" ]; then
    envsubst < k8s/policy.yaml | kubectl apply -f -
fi

# Apply deployment
envsubst < k8s/deployment.yaml | kubectl apply -f -

# Apply service
envsubst < k8s/service.yaml | kubectl apply -f -

# Apply ingress
envsubst < k8s/ingress.yaml | kubectl apply -f -

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s

# Get service information
echo -e "${GREEN}Deployment completed successfully!${NC}"
kubectl get pods -n $NAMESPACE -l app=$APP_NAME
kubectl get service -n $NAMESPACE $SERVICE_NAME

echo -e "${GREEN}✅ Application deployed successfully!${NC}"
