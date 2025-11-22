# OpenChat Helm Chart

This Helm chart deploys the OpenChat Django application along with its dependencies (PostgreSQL and Redis) to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- kubectl configured to communicate with your cluster

## Installation

### Basic Installation

```bash
helm install openchat ./helm/openchat \
  --namespace openchat \
  --create-namespace
```

### Custom Installation with Values

```bash
helm install openchat ./helm/openchat \
  --namespace openchat \
  --create-namespace \
  --set web.image.repository=ghcr.io/your-repo \
  --set web.image.tag=latest \
  --set ingress.hosts[0].host=yourdomain.com
```

### Installation with Custom Values File

Create a `custom-values.yaml` file:

```yaml
web:
  image:
    repository: ghcr.io/your-repo
    tag: latest

  imagePullSecrets:
    - name: ghcr-secret

ingress:
  hosts:
    - host: yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - yourdomain.com
      secretName: ssl-cert-prod

certManager:
  production:
    email: your-email@example.com
```

Then install:

```bash
helm install openchat ./helm/openchat \
  --namespace openchat \
  --create-namespace \
  -f custom-values.yaml
```

## Upgrading

```bash
helm upgrade openchat ./helm/openchat \
  --namespace openchat \
  --set web.image.tag=new-version
```

## Uninstallation

```bash
helm uninstall openchat --namespace openchat
```

## Configuration

The following table lists the configurable parameters of the OpenChat chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Kubernetes namespace | `openchat` |
| `global.environment` | Environment name | `development` |
| `web.image.repository` | Web application image repository | `ghcr.io/PLACEHOLDER_REPO` |
| `web.image.tag` | Web application image tag | `development-latest` |
| `web.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `web.replicaCount` | Number of web replicas | `1` |
| `web.service.type` | Kubernetes service type | `ClusterIP` |
| `web.service.port` | Service port | `80` |
| `web.resources.requests.memory` | Memory request | `256Mi` |
| `web.resources.requests.cpu` | CPU request | `200m` |
| `web.resources.limits.memory` | Memory limit | `512Mi` |
| `web.resources.limits.cpu` | CPU limit | `500m` |
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.image.tag` | PostgreSQL image tag | `16-alpine` |
| `postgresql.persistence.enabled` | Enable persistence | `true` |
| `postgresql.persistence.size` | PVC size | `10Gi` |
| `redis.enabled` | Enable Redis | `true` |
| `redis.image.tag` | Redis image tag | `7-alpine` |
| `redis.persistence.enabled` | Enable persistence | `true` |
| `redis.persistence.size` | PVC size | `5Gi` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `certManager.enabled` | Enable cert-manager resources | `true` |

## Architecture

This chart deploys:

- **Web Application**: Django application (configurable replicas)
- **PostgreSQL**: Single replica database with persistent storage
- **Redis**: Single replica cache with persistent storage
- **Ingress**: NGINX ingress with TLS support
- **Cert Manager**: Let's Encrypt certificate issuers (staging and production)

## Secrets

This chart expects a Kubernetes secret named `openchat-secrets` to exist in the namespace with the following keys:

- `POSTGRES_DB`: PostgreSQL database name
- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- Additional application secrets as needed

Create the secret manually:

```bash
kubectl create secret generic openchat-secrets \
  --namespace openchat \
  --from-literal=POSTGRES_DB=openchat \
  --from-literal=POSTGRES_USER=openchat \
  --from-literal=POSTGRES_PASSWORD=your-secure-password
```

## Monitoring

Check deployment status:

```bash
# List all resources
kubectl get all -n openchat

# Check pod logs
kubectl logs -l app=openchat,component=web -n openchat --tail=100

# Check Helm release status
helm status openchat -n openchat
```

## Troubleshooting

### Pods not starting

```bash
kubectl describe pods -n openchat
kubectl logs -l app=openchat -n openchat
```

### Database connection issues

```bash
kubectl exec -it -n openchat deployment/openchat-db -- psql -U openchat
```

### Redis connection issues

```bash
kubectl exec -it -n openchat deployment/openchat-redis -- redis-cli ping
```

## Development

To test template rendering without installing:

```bash
helm template openchat ./helm/openchat \
  --namespace openchat \
  --debug
```

To validate the chart:

```bash
helm lint ./helm/openchat
```
