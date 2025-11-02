# Kubernetes Manifests for k3s Deployment

This directory contains Kubernetes manifests for deploying the Django Chat application to k3s on Raspberry Pi.

## Prerequisites

1. k3s cluster running on Raspberry Pi
2. kubectl configured to access the k3s cluster
3. Docker image registry (GitHub Container Registry is used by default)
4. Secrets configured in Kubernetes

## Setup Instructions

### 1. Create Kubernetes Secrets

You need to create a secret with your application secrets. You can do this manually or use the template below:

```bash
kubectl create secret generic openchat-secrets \
  --from-literal=DJANGO_SECRET_KEY='your-secret-key-here' \
  --from-literal=POSTGRES_DB='openchat' \
  --from-literal=POSTGRES_USER='openchat' \
  --from-literal=POSTGRES_PASSWORD='your-postgres-password' \
  --namespace=openchat
```

Or create a secret YAML file (don't commit this with real secrets):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openchat-secrets
  namespace: openchat
type: Opaque
stringData:
  DJANGO_SECRET_KEY: "your-secret-key-here"
  POSTGRES_DB: "openchat"
  POSTGRES_USER: "openchat"
  POSTGRES_PASSWORD: "your-postgres-password"
  # Add any other secrets your application needs
```

### 2. Update Image Reference

Update `deployment.yaml` with your actual image repository:
- Replace `USERNAME/REPOSITORY` with your GitHub username and repository name
- Or use your own container registry

### 3. Configure Ingress (Optional)

If you want to expose the application via a domain name:
- Update `ingress.yaml` with your domain
- Configure DNS to point to your Raspberry Pi's IP
- Ensure Traefik (or your ingress controller) is installed in k3s

### 4. Deploy

The CI/CD pipeline will automatically deploy when you push to the `development` branch.

To deploy manually:

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Create secrets (if not already created)
kubectl apply -f secret.yaml

# Deploy database and redis
kubectl apply -f postgres-pvc.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f redis-pvc.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

# Deploy application
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Deploy ingress (optional)
kubectl apply -f ingress.yaml
```

## GitHub Secrets Required

For the CI/CD pipeline to work, configure these secrets in GitHub:

### k3s Deployment Secrets:
- `K3S_KUBECONFIG`: Base64-encoded kubeconfig file content
- `K3S_NAMESPACE`: Kubernetes namespace (default: openchat)
- `K3S_REGISTRY_URL`: Container registry URL (if using private registry)
- `K3S_REGISTRY_USERNAME`: Registry username (if using private registry)
- `K3S_REGISTRY_PASSWORD`: Registry password (if using private registry)
- `K3S_REGISTRY_SECRET`: Set to "true" if you need to create image pull secrets

### AWS Deployment Secrets (for master branch):
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_REGION`: AWS region
- `EB_APPLICATION_NAME`: Elastic Beanstalk application name
- `EB_ENVIRONMENT_NAME`: Elastic Beanstalk environment name

### Other Secrets:
- `CODECOV_TOKEN`: Codecov token for coverage reports

## Getting k3s Kubeconfig

To get your k3s kubeconfig for the CI/CD pipeline:

```bash
# On your Raspberry Pi
sudo cat /etc/rancher/k3s/k3s.yaml | base64 -w 0
```

### Network Setup Options

**⚠️ IMPORTANT**: Your k3s cluster needs to be accessible from GitHub Actions. See [NETWORK_SETUP.md](./NETWORK_SETUP.md) for detailed instructions.

**Quick Recommendations**:
- **For Development**: Use **ngrok** (easiest, most secure)
- **For Production**: Use **Tailscale VPN** (most secure)
- **Alternative**: Direct public IP (requires router port forwarding)

Update the server URL in the kubeconfig to be accessible from GitHub Actions:
- ngrok: `https://8.tcp.ngrok.io:13621` (use your actual ngrok URL)
  - **Important**: Must add `insecure-skip-tls-verify: true` for ngrok TCP tunnels
  - Use `./k8s/ngrok-k3s-setup.sh` script to auto-configure
- Public IP: `https://YOUR_PUBLIC_IP:6443`
- Tailscale: `https://YOUR_TAILSCALE_IP:6443`

**Quick setup with your ngrok URL**:
```bash
cd k8s
./ngrok-k3s-setup.sh tcp://8.tcp.ngrok.io:13621
cat k3s-ngrok.yaml | base64 -w 0
```

## Storage

The manifests use PersistentVolumeClaims for PostgreSQL and Redis data. Make sure your k3s cluster has a default storage class configured, or update the PVC specifications.
