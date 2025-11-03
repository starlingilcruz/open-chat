# CI/CD Improvements Summary

## Overview

This document outlines the improvements made to the CI/CD pipeline and the setup required for deploying to both AWS Elastic Beanstalk (master branch) and k3s on Raspberry Pi (development branch).

## Key Improvements

### 1. **Consistent Python Version**
- Fixed Python version inconsistency (now uses 3.11 consistently across test and deployment jobs)
- Matches the Dockerfile Python version

### 2. **Better Caching**
- Uses GitHub Actions cache for pip dependencies
- Uses Docker Buildx cache (GitHub Actions cache type) for faster Docker builds
- Improved cache key strategy

### 3. **Concurrency Control**
- Added concurrency groups to cancel in-progress runs when new commits are pushed
- Prevents unnecessary workflow runs

### 4. **Improved Error Handling**
- Added timeout limits for all jobs
- Better conditional execution
- Always uploads coverage reports even on failure

### 5. **Docker Image Building**
- Multi-platform builds (linux/amd64, linux/arm64) for Raspberry Pi compatibility
- Automatic image tagging with branch and commit SHA
- Images pushed to GitHub Container Registry (ghcr.io)

### 6. **Security Improvements**
- Uses official AWS credentials action instead of manual credential file creation
- Proper secret handling
- Image pull secrets for private registries

### 7. **Better Workflow Structure**
- Clear job dependencies
- Separate jobs for test, build, and deploy
- Environment-specific deployments

### 8. **Kubernetes Deployment**
- Complete k8s manifests for k3s deployment
- Health checks and resource limits
- Persistent volumes for database and Redis
- ConfigMap for configuration management

## Branch Strategy

### Master Branch
- Runs tests and linting
- Builds Docker image (for validation)
- Deploys to **AWS Elastic Beanstalk**

### Development Branch
- Runs tests and linting
- Builds and pushes Docker image to GitHub Container Registry
- Deploys to **k3s on Raspberry Pi**

### Pull Requests
- Runs tests and linting only
- No deployments

## Setup Requirements

### GitHub Secrets

#### For AWS Deployment (Master Branch)
```
AWS_ACCESS_KEY_ID          # AWS access key
AWS_SECRET_ACCESS_KEY      # AWS secret key
AWS_REGION                 # AWS region (e.g., us-east-1)
EB_APPLICATION_NAME        # Elastic Beanstalk application name
EB_ENVIRONMENT_NAME        # Elastic Beanstalk environment name
```

#### For k3s Deployment (Development Branch)
```
K3S_KUBECONFIG            # Base64-encoded kubeconfig file
K3S_NAMESPACE             # Kubernetes namespace (default: openchat)
K3S_REGISTRY_URL          # Container registry URL (optional, if using private registry)
K3S_REGISTRY_USERNAME     # Registry username (optional)
K3S_REGISTRY_PASSWORD     # Registry password (optional)
K3S_REGISTRY_SECRET       # Set to "true" if registry secrets needed
```

#### For Code Coverage
```
CODECOV_TOKEN             # Codecov API token
```

### Getting k3s Kubeconfig

**📖 See [k8s/NETWORK_SETUP.md](./k8s/NETWORK_SETUP.md) for complete network setup guide**

**Quick Setup (Recommended: ngrok)**:

1. **On your Raspberry Pi**, install and setup ngrok:
   ```bash
   # Install ngrok
   curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
     sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
     echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
     sudo tee /etc/apt/sources.list.d/ngrok.list && \
     sudo apt update && sudo apt install ngrok

   # Get authtoken from https://dashboard.ngrok.com
   ngrok config add-authtoken YOUR_AUTHTOKEN

   # Start tunnel (for k3s API port 6443)
   ngrok tcp 6443
   ```

2. **Get your Raspberry Pi's public IP** (if using direct access):
   ```bash
   curl ifconfig.me
   ```
   Or use ngrok's tunnel URL (recommended for development).

3. **Get and update kubeconfig**:
   ```bash
   # Get kubeconfig
   sudo cat /etc/rancher/k3s/k3s.yaml > k3s.yaml

   # Update server URL (replace with ngrok URL or public IP)
   # For ngrok: server: https://0.tcp.ngrok.io:12345
   # For public IP: server: https://YOUR_PUBLIC_IP:6443
   nano k3s.yaml

   # Base64 encode
   cat k3s.yaml | base64 -w 0
   ```

4. **Add to GitHub Secrets** as `K3S_KUBECONFIG`

**Why ngrok is better for development**:
- ✅ No router port forwarding needed
- ✅ More secure (tunneled)
- ✅ Works behind NAT/firewall
- ✅ Easy to set up
- ✅ Free tier available

### Setting up Kubernetes Secrets

Before the first deployment, you need to create secrets in your k3s cluster:

```bash
kubectl create namespace openchat

kubectl create secret generic openchat-secrets \
  --from-literal=DJANGO_SECRET_KEY='your-secret-key-here' \
  --from-literal=POSTGRES_DB='openchat' \
  --from-literal=POSTGRES_USER='openchat' \
  --from-literal=POSTGRES_PASSWORD='your-postgres-password' \
  --namespace=openchat
```

### Container Registry Permissions

For the GitHub Container Registry (ghcr.io):
1. Go to your repository settings
2. Navigate to "Actions" → "General"
3. Under "Workflow permissions", ensure "Read and write permissions" is selected
4. This allows the workflow to push images to ghcr.io

### Updating Kubernetes Manifests

The `k8s/deployment.yaml` file contains a placeholder image:
```yaml
image: ghcr.io/PLACEHOLDER_REPO:development-latest
```

The CI/CD pipeline automatically replaces this with the correct image tag during deployment. You don't need to modify it manually.

## Deployment Flow

### Master Branch (Production)
1. Code pushed to master
2. Tests and linting run
3. Docker image built (validation only)
4. Code deployed to AWS Elastic Beanstalk using EB CLI
5. Health check verifies deployment

### Development Branch (Staging)
1. Code pushed to development
2. Tests and linting run
3. Docker image built for both amd64 and arm64
4. Image pushed to GitHub Container Registry
5. Kubernetes manifests prepared with correct image tag
6. Deployed to k3s cluster
7. Waits for rollout completion
8. Verifies deployment status

## Manual Deployment

If you need to deploy manually to k3s:

```bash
# Set your image tag
export IMAGE_TAG="ghcr.io/your-username/your-repo:development-abc123"

# Update deployment.yaml
sed -i "s|image:.*|image: $IMAGE_TAG|g" k8s/deployment.yaml

# Apply manifests
kubectl apply -f k8s/
```

## Troubleshooting

### Docker Build Fails
- Check Dockerfile syntax
- Verify multi-platform build is supported
- Check GitHub Actions logs for specific errors

### k3s Deployment Fails
- Verify kubeconfig is correct and accessible from GitHub Actions
- Check that secrets exist in the namespace
- Ensure storage class is configured for PVCs
- Check pod logs: `kubectl logs -n openchat deployment/openchat-web`

### Image Pull Errors
- Verify image exists in registry: `docker pull ghcr.io/username/repo:tag`
- Check registry permissions
- Verify image pull secrets if using private registry

## Best Practices Applied

✅ **Consistent versions** - Python 3.11 everywhere
✅ **Proper caching** - Multiple cache layers for speed
✅ **Concurrency control** - Prevents duplicate runs
✅ **Security** - Proper credential handling
✅ **Resource limits** - CPU and memory limits in k8s
✅ **Health checks** - Liveness and readiness probes
✅ **Rolling updates** - Kubernetes handles zero-downtime deployments
✅ **Multi-platform** - Supports both amd64 and arm64
✅ **Artifact retention** - Coverage reports saved for 30 days
✅ **Timeouts** - All jobs have timeout limits

## Next Steps

1. Configure GitHub secrets as listed above
2. Create Kubernetes secrets in your k3s cluster
3. Test the workflow by pushing to the development branch
4. Verify deployment on your Raspberry Pi
5. Adjust resource limits in k8s manifests if needed
6. Configure ingress for external access (optional)

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [k3s Documentation](https://k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/)
