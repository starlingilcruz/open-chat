# Cluster-Wide Kubernetes Resources

This directory contains cluster-wide Kubernetes resources that are managed **outside of Helm** and shared across multiple applications.

## Contents

### Cert-Manager Resources

These resources configure Let's Encrypt certificate issuers and SSL certificates for the cluster:

- **cert-issuer-staging.yaml** - Let's Encrypt staging issuer (for testing)
- **cert-issuer-prod.yaml** - Let's Encrypt production issuer
- **certificate-staging.yaml** - Staging SSL certificate
- **certificate-prod.yaml** - Production SSL certificate

## Why Separate from Helm?

These resources are kept separate because:

1. **Cluster-wide scope** - ClusterIssuers are cluster-level resources
2. **Shared across apps** - Multiple applications use the same certificate issuers
3. **Lifecycle management** - Managed independently from application deployments
4. **Avoid conflicts** - Prevents Helm adoption/ownership issues

## Application Resources

All application-specific resources (deployments, services, configmaps, etc.) are now managed by the **Helm chart** in `helm/openchat/`.

To deploy the application:
```bash
helm upgrade --install openchat ./helm/openchat \
  --namespace openchat \
  --create-namespace
```

## Applying These Resources

To apply cert-manager resources manually:
```bash
kubectl apply -f k8s/cert-issuer-staging.yaml
kubectl apply -f k8s/cert-issuer-prod.yaml
kubectl apply -f k8s/certificate-staging.yaml
kubectl apply -f k8s/certificate-prod.yaml
```

Note: These are typically applied once during initial cluster setup and rarely changed.
