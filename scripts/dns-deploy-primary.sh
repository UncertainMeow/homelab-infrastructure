#!/bin/bash
# DNS Primary Node Deployment Script

set -e

DNS_NODE_DIR="/opt/dns-primary"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs/dns-primary"

echo "🚀 Starting DNS Primary Node Deployment"
echo "======================================"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root or with sudo"
   exit 1
fi

# Create deployment directory
echo "📁 Creating deployment directory..."
mkdir -p "$DNS_NODE_DIR"
cd "$DNS_NODE_DIR"

# Copy configuration files
echo "📋 Copying configuration files..."
cp -r "$CONFIG_DIR"/* .

# Create required directories
echo "📂 Creating required directories..."
mkdir -p dns-config dns-logs tailscale-data ssl-certs monitoring

# Set proper permissions
chown -R 1000:1000 dns-config dns-logs
chmod 755 tailscale-data ssl-certs

# Check for environment file
if [[ ! -f ".env" ]]; then
    echo "⚠️  .env file not found. Please copy .env.template to .env and configure:"
    echo "   cp .env.template .env"
    echo "   nano .env"
    echo ""
    echo "Required variables:"
    echo "   - TS_AUTHKEY (Tailscale auth key)"
    echo "   - TECHNITIUM_ADMIN_PASSWORD (strong password)"
    echo "   - CLOUDFLARE_API_TOKEN (for SSL certs)"
    echo "   - CLOUDFLARE_EMAIL (your Cloudflare email)"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
echo "✅ Validating configuration..."
required_vars=("TS_AUTHKEY" "TECHNITIUM_ADMIN_PASSWORD")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ Required environment variable $var is not set"
        exit 1
    fi
done

# Start the services
echo "🐳 Starting DNS services..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check service health
echo "🏥 Checking service health..."
if docker compose ps | grep -q "Up"; then
    echo "✅ Services are running"
else
    echo "❌ Some services failed to start"
    docker compose logs
    exit 1
fi

# Get Tailscale status
echo "📡 Getting Tailscale status..."
TAILSCALE_IP=$(docker compose exec -T tailscale-dns tailscale ip -4 2>/dev/null || echo "Not connected")
echo "   Tailscale IP: $TAILSCALE_IP"

# Display connection information
echo ""
echo "🎉 DNS Primary Node Deployed Successfully!"
echo "========================================"
echo "📍 Local Access:    http://localhost:5380"
if [[ "$TAILSCALE_IP" != "Not connected" ]]; then
    echo "📍 Tailscale Access: http://$TAILSCALE_IP:5380"
fi
echo "👤 Admin User:      admin"
echo "🔑 Admin Password:  (from .env file)"
echo ""
echo "Next Steps:"
echo "1. Access the web interface and complete initial setup"
echo "2. Configure DoH and ad blocking"
echo "3. Set up split-horizon DNS for your services"
echo ""
echo "📚 Logs: docker compose logs -f"
echo "🔄 Restart: docker compose restart"
echo "🛑 Stop: docker compose down"