#!/bin/bash
# Quick script to setup kubeconfig with ngrok tunnel for k3s

set -e

echo "🔧 Setting up kubeconfig with ngrok tunnel..."

# Get ngrok tunnel info
NGROK_URL="${1:-tcp://8.tcp.ngrok.io:13621}"

if [[ ! $NGROK_URL =~ ^tcp:// ]]; then
    echo "❌ Error: Invalid ngrok URL format. Expected: tcp://HOST:PORT"
    echo "Usage: $0 tcp://8.tcp.ngrok.io:13621"
    exit 1
fi

# Extract host and port from ngrok URL
NGROK_HOST=$(echo $NGROK_URL | sed 's|tcp://||' | cut -d: -f1)
NGROK_PORT=$(echo $NGROK_URL | sed 's|tcp://||' | cut -d: -f2)

echo "📡 Using ngrok tunnel: $NGROK_HOST:$NGROK_PORT"

# Get original kubeconfig
echo "📋 Getting kubeconfig from k3s..."
sudo cp /etc/rancher/k3s/k3s.yaml k3s-ngrok.yaml

# Update server URL
echo "✏️  Updating server URL to use ngrok tunnel..."
sed -i "s|server:.*|server: https://${NGROK_HOST}:${NGROK_PORT}|g" k3s-ngrok.yaml

# For ngrok TCP tunnels, we need to skip TLS verification or configure properly
# This is a development setup, so we'll add insecure-skip-tls-verify
if ! grep -q "insecure-skip-tls-verify" k3s-ngrok.yaml; then
    echo "⚠️  Adding insecure-skip-tls-verify for ngrok tunnel (development only)"
    sed -i '/certificate-authority-data:/a\    insecure-skip-tls-verify: true' k3s-ngrok.yaml
fi

# Comment out the certificate-authority-data line if present
sed -i 's/^    certificate-authority-data:/    # certificate-authority-data:/g' k3s-ngrok.yaml

echo ""
echo "✅ Updated kubeconfig saved to: k3s-ngrok.yaml"
echo ""
echo "🧪 Testing connection..."
echo "   kubectl --kubeconfig k3s-ngrok.yaml get nodes"
echo ""
echo "📋 To base64 encode for GitHub Secrets:"
echo "   cat k3s-ngrok.yaml | base64 -w 0"
echo ""
echo "⚠️  IMPORTANT: This uses insecure-skip-tls-verify (development only!)"
echo "   For production, consider using Tailscale or ngrok with proper TLS configuration"
