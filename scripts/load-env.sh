#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | grep -v '#' | grep -v '^$' | xargs)
    echo "Environment variables loaded successfully!"
else
    echo "Warning: .env file not found in project root"
    exit 1
fi

# Validate required variables
required_vars=("AWS_REGION" "DOCKER_USERNAME" "APP_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

echo "All required environment variables are set!"
