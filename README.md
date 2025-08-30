# Secure Supply Chain CI/CD on AWS with Docker Hub

A production-ready secure supply chain CI/CD pipeline built with AWS EKS and Docker Hub, featuring image signing, vulnerability scanning, and policy enforcement.

## 🏗️ Architecture

```
GitHub Repository
       ↓
GitHub Actions (CI/CD)
       ↓
Docker Hub (Container Registry)
       ↓
AWS EKS (Kubernetes Cluster)
       ↓
Application Deployment
```

## 🔒 Security Features

- **Image Signing**: Cosign for container image signing and verification
- **Vulnerability Scanning**: Trivy for container vulnerability scanning
- **SBOM Generation**: Syft for Software Bill of Materials
- **Policy Enforcement**: Kyverno for Kubernetes policy enforcement
- **Non-root Containers**: Security context with non-root user execution
- **Resource Limits**: CPU and memory limits for all containers
- **Health Checks**: Liveness and readiness probes

## 📋 Prerequisites

### Required Tools
- [AWS CLI](https://aws.amazon.com/cli/) (v2.x)
- [Terraform](https://www.terraform.io/) (v1.0+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Git](https://git-scm.com/)

### Accounts Required
- AWS account with appropriate permissions
- Docker Hub account
- GitHub account

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd secure-supply-chain-cicd
chmod +x scripts/setup.sh
```

### 2. Run Setup Script

```bash
./scripts/setup.sh
```

This script will:
- Check prerequisites
- Configure AWS credentials
- Deploy AWS infrastructure (EKS, IAM)
- Configure kubectl
- Provide GitHub secrets setup instructions

### 3. Configure GitHub Secrets

After running the setup script, add the following secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Add the following secrets:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: (provided by setup script)
   - **Name**: `DOCKER_USERNAME`
   - **Value**: Your Docker Hub username
   - **Name**: `DOCKER_PASSWORD`
   - **Value**: Your Docker Hub password or access token

**💡 Pro Tip**: Use a Docker Hub access token instead of your password for better security.

### 4. Test the Pipeline

Push your code to trigger the CI/CD pipeline:

```bash
git add .
git commit -m "Initial commit with Docker Hub + AWS CI/CD"
git push origin main
```

## 🧪 Testing Your Deployment

### 1. Monitor Pipeline

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Monitor the workflow execution

### 2. Verify Deployment

```bash
# Check if pods are running
kubectl get pods

# Check services
kubectl get services

# Get Load Balancer URL
kubectl get service secure-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 3. Test Application

```bash
# Get the Load Balancer URL
LB_URL=$(kubectl get service secure-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the application
curl http://$LB_URL
```

### 4. Verify Security Features

```bash
# Check Kyverno policies
kubectl get clusterpolicies

# Check image verification
kubectl describe clusterpolicy verify-signed-images

# View logs
kubectl logs -l app=secure-app
```

## 📁 Project Structure

```
secure-supply-chain-cicd/
├── app/                    # Application code
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── .github/workflows/      # GitHub Actions
│   └── ci-cd.yaml
├── k8s/                   # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── policy.yaml
├── terraform/             # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── kubernetes.tf
│   ├── outputs.tf
│   └── versions.tf
├── scripts/               # Setup and cleanup scripts
│   ├── setup.sh
│   ├── cleanup.sh
│   └── test-pipeline.sh
└── README.md
```

## 🔧 Configuration

### AWS Resources Created

- **EKS Cluster**: Kubernetes cluster with 1-2 t3.small nodes
- **VPC**: Custom VPC with public/private subnets
- **IAM Roles**: Roles for GitHub Actions and EKS
- **Load Balancer**: Application Load Balancer for external access

### Docker Hub Integration

- Images are built and pushed to Docker Hub
- Uses your Docker Hub credentials from GitHub secrets
- Supports both tagged and latest image versions
- Images are signed with Cosign for verification

### Cost Optimization

This setup is designed to stay within AWS free tier:
- Single NAT Gateway (instead of multiple)
- Minimal EKS node group (1-2 nodes)
- t3.small instances (free tier eligible)
- Resource limits on containers

**Note**: Docker Hub is free for public repositories. Private repositories may have usage limits.

## 🛠️ Troubleshooting

### Common Issues

1. **AWS Credentials Not Configured**
   ```bash
   aws configure
   ```

2. **Terraform State Issues**
   ```bash
   cd terraform
   terraform init
   terraform plan
   ```

3. **kubectl Connection Issues**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name secure-supply-chain-cluster
   ```

4. **GitHub Actions Failures**
   - Check if `AWS_ROLE_ARN`, `DOCKER_USERNAME`, and `DOCKER_PASSWORD` secrets are set correctly
   - Verify repository permissions
   - Check workflow logs for specific errors

5. **Docker Hub Authentication Issues**
   - Ensure `DOCKER_USERNAME` and `DOCKER_PASSWORD` are set correctly
   - Use Docker Hub access token instead of password
   - Check Docker Hub rate limits

### Debug Commands

```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes

# Check all resources
kubectl get all

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check logs
kubectl logs -l app=secure-app

# Test Docker Hub login
docker login -u your-username -p your-password
```

## 🧹 Cleanup

To remove all AWS resources:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

**Note**: This will not remove images from Docker Hub. You'll need to manually delete them if desired.

## 📊 Monitoring and Logging

### View Application Logs
```bash
kubectl logs -l app=secure-app -f
```

### Monitor Resource Usage
```bash
kubectl top pods
kubectl top nodes
```

### Check Security Scans
- View Trivy scan results in GitHub Actions logs
- Download SBOM artifacts from GitHub Actions
- Check Kyverno policy violations

### Docker Hub Monitoring
- Check image push/pull status in GitHub Actions
- Monitor Docker Hub rate limits
- Verify image signing in GitHub Actions logs

## 🔐 Security Best Practices

1. **Image Signing**: All images are signed with Cosign
2. **Vulnerability Scanning**: Trivy scans for CVEs
3. **Policy Enforcement**: Kyverno blocks unsigned images
4. **Non-root Execution**: Containers run as non-root user
5. **Resource Limits**: Prevents resource exhaustion
6. **Network Policies**: Restrict pod-to-pod communication
7. **Docker Hub Security**: Use access tokens instead of passwords

## 📈 Production Readiness Checklist

- [x] Automated CI/CD pipeline
- [x] Container image signing and verification
- [x] Vulnerability scanning
- [x] SBOM generation
- [x] Policy enforcement
- [x] Health checks and monitoring
- [x] Resource limits and security context
- [x] Load balancer for external access
- [x] Infrastructure as Code
- [x] Automated cleanup scripts
- [x] Docker Hub integration
- [x] Secure credential management

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter any issues:

1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Check AWS CloudWatch logs
4. Verify Docker Hub credentials and rate limits
5. Open an issue in the repository

---

**Note**: This setup uses AWS free tier resources and Docker Hub free tier. Monitor your AWS billing and Docker Hub usage to ensure you stay within limits.
