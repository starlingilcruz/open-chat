# Network Setup Guide for k3s Deployment

This guide explains different options for connecting GitHub Actions to your k3s cluster on Raspberry Pi.

## Option Comparison

| Feature | Public IP | ngrok | Tailscale/VPN |
|---------|-----------|-------|---------------|
| **Security** | ⚠️ Lower (exposed port) | ✅ Better (tunnel) | ✅✅ Best (private network) |
| **Setup Complexity** | ⚠️ Medium (port forwarding) | ✅ Easy | ⚠️ Medium |
| **Cost** | ✅ Free | ✅ Free (basic) / 💰 Paid (fixed domain) | ✅ Free (personal) |
| **Stability** | ⚠️ Depends on ISP | ✅ Very stable | ✅ Very stable |
| **Best For** | Production | Development/Staging | Any (most secure) |

**Recommendation for Development: Use ngrok** 🎯

## Option 1: Using ngrok (Recommended for Development)

Ngrok creates a secure tunnel to your Raspberry Pi without exposing it directly to the internet.

### Advantages
- ✅ No router port forwarding needed
- ✅ More secure (tunneled connection)
- ✅ Easy to set up
- ✅ Free tier available
- ✅ Works behind NAT/firewall
- ✅ Can get fixed domain with paid plan

### Setup Instructions

#### 1. Install ngrok on Raspberry Pi

```bash
# Download and install ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list && \
  sudo apt update && sudo apt install ngrok

# Or using snap
sudo snap install ngrok
```

#### 2. Sign up for ngrok account
1. Go to https://dashboard.ngrok.com/signup
2. Sign up for a free account
3. Get your authtoken from the dashboard

#### 3. Configure ngrok

```bash
# Authenticate
ngrok config add-authtoken YOUR_AUTHTOKEN

# Test connection to k3s API (port 6443)
ngrok tcp 6443
```

Note: The free tier gives you a random URL each time. For CI/CD, you'll want to use the paid tier with a fixed domain, or use the ngrok API to get the current URL.

#### 4. Use ngrok API to get current tunnel URL (Free Tier)

For free tier, you can use ngrok's API to get the current tunnel URL:

```bash
# Get current ngrok tunnel info
curl http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'
```

#### 5. Update kubeconfig for GitHub Actions

Since ngrok URLs change with free tier, you have two options:

**Option A: Use ngrok's API endpoint (Requires ngrok web interface)**

1. Start ngrok with web interface:
   ```bash
   ngrok tcp 6443 --log stdout
   ```

2. Access the API at `http://YOUR_NGROK_DOMAIN:4040` (if using ngrok HTTP tunnel) or use the local API.

**Option B: Use ngrok with fixed domain (Paid tier recommended)**

```bash
# Start ngrok with fixed domain (requires paid plan)
ngrok tcp 6443 --remote-addr YOUR_FIXED_DOMAIN.tcp.ngrok.io:PORT
```

#### 6. Setup ngrok as a systemd service (for auto-start)

Create `/etc/systemd/system/ngrok-k3s.service`:

```ini
[Unit]
Description=ngrok tunnel for k3s
After=network.target

[Service]
Type=simple
User=YOUR_USER
ExecStart=/usr/local/bin/ngrok tcp 6443 --log stdout
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemd enable ngrok-k3s.service
sudo systemd start ngrok-k3s.service
```

#### 7. Get the ngrok URL for kubeconfig

The ngrok TCP tunnel URL will look like: `tcp://0.tcp.ngrok.io:12345`

Extract the host and port:
- Host: `0.tcp.ngrok.io`
- Port: `12345`

#### 8. Update kubeconfig

```bash
# On your Raspberry Pi, get the current kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > k3s.yaml

# Edit the kubeconfig to use ngrok URL
# Replace the server line:
# OLD: server: https://127.0.0.1:6443
# NEW: server: https://0.tcp.ngrok.io:12345
# BUT WAIT - ngrok TCP tunnels need special handling!

# Actually, for k3s HTTPS, you need ngrok's TCP proxy
# The server URL should be: https://0.tcp.ngrok.io:12345
# But you'll need to add TLS skip (not recommended for production)

# Better: Use ngrok's HTTPS endpoint if available, or configure properly
```

**Important**: For k3s HTTPS API, you need to handle TLS certificates. Options:
1. Use ngrok's HTTPS endpoints (if available on your plan)
2. Use `--insecure-skip-tls-verify` in kubeconfig (development only)
3. Configure ngrok to preserve the original TLS

#### 9. For GitHub Actions, update the workflow to handle dynamic ngrok URLs

If using free tier with changing URLs, you could:
- Store the ngrok API endpoint as a secret
- Have GitHub Actions query the current tunnel URL
- Update kubeconfig dynamically

However, **for simplicity, a fixed domain (paid ngrok) or the next option is better.**

## Option 2: Using Public IP (Direct Access)

### Finding Your Raspberry Pi's Public IP

#### Method 1: From Raspberry Pi itself
```bash
# Get public IP
curl ifconfig.me
# or
curl icanhazip.com
# or
curl ipinfo.io/ip
```

#### Method 2: From any device
- Visit https://whatismyipaddress.com/ (shows your router's public IP)
- This is the IP you need to use

**Important**: Your Raspberry Pi's **local IP** (192.168.x.x) is different from your **public IP**. GitHub Actions needs the public IP.

### Setup Requirements

1. **Router Port Forwarding**:
   - Access your router admin panel (usually 192.168.1.1 or 192.168.0.1)
   - Forward external port 6443 → Raspberry Pi's local IP:6443
   - Example: `WAN:6443 → 192.168.1.100:6443`

2. **Firewall Configuration** (on Raspberry Pi):
   ```bash
   # Allow port 6443 (k3s API)
   sudo ufw allow 6443/tcp
   ```

3. **Dynamic DNS** (if IP changes):
   - Your ISP may assign a dynamic IP
   - Use a DDNS service like DuckDNS, No-IP, or Cloudflare
   - Update kubeconfig server URL to use the DDNS domain

4. **Security Considerations**:
   - ⚠️ Exposing k3s API directly is a security risk
   - Consider using a VPN or restricting access by IP
   - Use firewall rules to limit access
   - Regularly rotate certificates

### Update kubeconfig

```bash
# Get your public IP
PUBLIC_IP=$(curl -s ifconfig.me)

# Update kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml | \
  sed "s|127.0.0.1:6443|${PUBLIC_IP}:6443|g" > k3s.yaml

# Base64 encode for GitHub
cat k3s.yaml | base64 -w 0
```

## Option 3: Using Tailscale (Most Secure - Recommended for Production)

Tailscale creates a secure mesh VPN between your devices.

### Setup

1. **Install Tailscale on Raspberry Pi**:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

2. **Get Tailscale IP**:
   ```bash
   tailscale ip -4
   # Example output: 100.x.x.x
   ```

3. **Update kubeconfig** to use Tailscale IP:
   ```bash
   TAILSCALE_IP=$(tailscale ip -4)
   sudo cat /etc/rancher/k3s/k3s.yaml | \
     sed "s|127.0.0.1:6443|${TAILSCALE_IP}:6443|g" > k3s.yaml
   ```

4. **Install Tailscale on GitHub Actions runner** (if self-hosted) OR:
   - Use Tailscale's API to create auth keys
   - Configure as a subnet router

**Note**: For GitHub-hosted runners, you'd need Tailscale's relay or use their API differently.

## Recommended Setup for Your Use Case

For **development/staging** (Raspberry Pi at home):

1. **Best Option: ngrok with fixed domain** (if budget allows)
   - Easiest setup
   - Secure
   - Stable connection
   - ~$8/month for fixed domain

2. **Good Free Option: Tailscale**
   - Most secure
   - Free for personal use
   - Works great if you can configure it

3. **Alternative Free Option: ngrok free tier + automation**
   - Free but requires some automation
   - URLs change on restart

4. **Last Resort: Public IP with firewall**
   - Only if you can't use other options
   - Add IP whitelisting if possible

## Quick Start: ngrok Setup Script

Save this as `setup-ngrok-k3s.sh`:

```bash
#!/bin/bash
set -e

echo "Setting up ngrok for k3s..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "Installing ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
      sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
      echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
      sudo tee /etc/apt/sources.list.d/ngrok.list && \
      sudo apt update && sudo apt install ngrok
fi

# Check if authtoken is set
if [ -z "$NGROK_AUTHTOKEN" ]; then
    echo "Please set NGROK_AUTHTOKEN environment variable"
    echo "Get it from: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
fi

# Configure ngrok
ngrok config add-authtoken $NGROK_AUTHTOKEN

# Start ngrok tunnel
echo "Starting ngrok tunnel for k3s (port 6443)..."
echo "Access the web interface at http://localhost:4040"
ngrok tcp 6443
```

## Security Best Practices

Regardless of which option you choose:

1. **Use strong authentication** - k3s tokens should be secure
2. **Limit access** - Use firewall rules to restrict who can connect
3. **Rotate certificates** - Regularly update k3s certificates
4. **Monitor access** - Log and monitor who accesses your cluster
5. **Use VPN/tunnel** - Prefer encrypted tunnels over direct exposure
6. **Update regularly** - Keep k3s and system updated

## Troubleshooting

### ngrok connection issues
- Check if ngrok is running: `pgrep ngrok`
- Check ngrok logs: `tail -f ~/.ngrok2/ngrok.log`
- Verify tunnel is active at http://localhost:4040

### Public IP not accessible
- Check router port forwarding
- Check firewall rules
- Verify ISP doesn't block incoming connections
- Some ISPs use CGNAT (no public IP) - use ngrok instead

### kubeconfig connection fails
- Verify the server URL is correct
- Check TLS certificate issues
- Try `kubectl --insecure-skip-tls-verify` (dev only)
- Verify port is open: `nc -zv YOUR_IP 6443`

## Next Steps

1. Choose your networking option
2. Follow the setup instructions
3. Test connection from your local machine
4. Update GitHub secrets with kubeconfig
5. Test deployment from GitHub Actions
