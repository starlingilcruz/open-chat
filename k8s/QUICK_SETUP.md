# Quick Setup: Using Your ngrok Tunnel

**Your ngrok URL**: `tcp://8.tcp.ngrok.io:13621` ✅

## Step 1: On Your Raspberry Pi

Run this script to automatically configure your kubeconfig:

```bash
cd /path/to/django-chat/k8s
./ngrok-k3s-setup.sh tcp://8.tcp.ngrok.io:13621
```

This will:
- ✅ Create `k3s-ngrok.yaml` with the correct server URL
- ✅ Configure TLS settings for ngrok
- ✅ Make it ready for GitHub Actions

## Step 2: Test the Connection

```bash
kubectl --kubeconfig k3s-ngrok.yaml get nodes
```

If you see your node listed, it's working! 🎉

## Step 3: Get Base64 for GitHub Secrets

```bash
cat k3s-ngrok.yaml | base64 -w 0
```

Copy the entire output.

## Step 4: Add to GitHub Secrets

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `K3S_KUBECONFIG`
5. Value: Paste the base64 string from Step 3
6. Click "Add secret"

## Step 5: Test Deployment

Push to the `development` branch and watch the GitHub Actions workflow deploy!

---

## Important Notes

⚠️ **ngrok URL Changes**: With the free tier, your ngrok URL changes every time you restart ngrok. You'll need to:
- Keep ngrok running continuously, OR
- Update the GitHub secret when the URL changes, OR
- Use ngrok's paid plan for a fixed domain

💡 **Keep ngrok Running**: Make sure ngrok stays running on your Raspberry Pi:

```bash
# Check if ngrok is running
pgrep ngrok

# If not running, start it:
ngrok tcp 6443

# Or set it up as a service (see NETWORK_SETUP.md)
```

---

## Manual Setup (if script doesn't work)

```bash
# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > k3s.yaml

# Update server URL
sed -i 's|server:.*|server: https://8.tcp.ngrok.io:13621|g' k3s.yaml

# Add insecure-skip-tls-verify (required for ngrok TCP tunnels)
sed -i '/server: https/a\    insecure-skip-tls-verify: true' k3s.yaml

# Comment out certificate-authority-data
sed -i 's/^    certificate-authority-data:/    # certificate-authority-data:/g' k3s.yaml

# Test
kubectl --kubeconfig k3s.yaml get nodes

# Encode
cat k3s.yaml | base64 -w 0
```
