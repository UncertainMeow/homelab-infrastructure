#!/bin/bash
# NetBox IPAM System Deployment Script
# Creates comprehensive network documentation and automation hub

set -e

NETBOX_DIR="/opt/netbox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs/netbox"

echo "🌐 Deploying NetBox IPAM System"
echo "==============================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root or with sudo"
   exit 1
fi

# Create deployment directory
echo "📁 Creating deployment directory..."
mkdir -p "$NETBOX_DIR"
cd "$NETBOX_DIR"

# Copy configuration files
echo "📋 Copying configuration files..."
cp -r "$CONFIG_DIR"/* .

# Create required directories
echo "📂 Creating required directories..."
mkdir -p {postgres-data,redis-data,redis-cache-data,netbox-media,netbox-reports,netbox-scripts,netbox-plugins,caddy-data,caddy-config,discovery-scripts/logs,discovery-scripts/exports}

# Set proper permissions
chmod 755 postgres-data redis-data redis-cache-data
chmod 777 netbox-media netbox-reports netbox-scripts netbox-plugins
chmod 755 discovery-scripts
chown -R 1000:1000 discovery-scripts/

# Check for environment file
if [[ ! -f ".env" ]]; then
    echo "⚠️  .env file not found. Please copy .env.template to .env and configure:"
    echo "   cp .env.template .env"
    echo "   nano .env"
    echo ""
    echo "Required variables to configure:"
    echo "   - POSTGRES_PASSWORD (strong database password)"
    echo "   - REDIS_PASSWORD (Redis password)"  
    echo "   - REDIS_CACHE_PASSWORD (Redis cache password)"
    echo "   - SECRET_KEY (50+ character random string)"
    echo "   - SUPERUSER_EMAIL (your email)"
    echo "   - SUPERUSER_PASSWORD (admin password)"
    echo "   - NETBOX_API_TOKEN (40-character hex token)"
    echo "   - CLOUDFLARE_API_TOKEN (for SSL certificates)"
    echo "   - TECHNITIUM_API_TOKEN (for DNS integration)"
    echo ""
    echo "🎲 Generate random values:"
    echo "   SECRET_KEY: $(openssl rand -hex 25)"
    echo "   NETBOX_API_TOKEN: $(openssl rand -hex 20)"
    echo "   POSTGRES_PASSWORD: $(openssl rand -base64 16)"
    echo "   REDIS_PASSWORD: $(openssl rand -base64 16)"
    echo "   REDIS_CACHE_PASSWORD: $(openssl rand -base64 16)"
    exit 1
fi

# Source environment variables
source .env

# Validate required environment variables
echo "✅ Validating configuration..."
required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "SECRET_KEY" "SUPERUSER_EMAIL" "SUPERUSER_PASSWORD" "NETBOX_API_TOKEN")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ Required environment variable $var is not set"
        exit 1
    fi
done

# Pull required images
echo "🐳 Pulling Docker images..."
docker compose pull

# Start the services
echo "🚀 Starting NetBox services..."
docker compose up -d postgres redis redis-cache

# Wait for database to be ready
echo "⏳ Waiting for database to initialize..."
sleep 30

# Check database health
echo "🏥 Checking database connectivity..."
if ! docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
    echo "❌ Database is not ready"
    docker compose logs postgres
    exit 1
fi

# Start NetBox application
echo "🌐 Starting NetBox application..."
docker compose up -d netbox netbox-worker

# Wait for NetBox to be ready
echo "⏳ Waiting for NetBox to initialize..."
sleep 60

# Check NetBox health
echo "🏥 Checking NetBox health..."
max_attempts=12
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    if curl -s -f "http://localhost:8080/api/" >/dev/null 2>&1; then
        echo "✅ NetBox is ready"
        break
    fi
    echo "   Attempt $attempt/$max_attempts - waiting for NetBox..."
    sleep 10
    ((attempt++))
done

if [[ $attempt -gt $max_attempts ]]; then
    echo "❌ NetBox failed to start properly"
    docker compose logs netbox
    exit 1
fi

# Start reverse proxy
echo "🔒 Starting Caddy reverse proxy..."
docker compose up -d netbox-caddy

# Start network discovery service
echo "🔍 Starting network discovery service..."
docker compose up -d netbox-discovery

# Perform initial network discovery
echo "🌍 Running initial network discovery..."
sleep 30

# Display service status
echo "📊 Checking service status..."
docker compose ps

# Get NetBox application details
echo ""
echo "🎉 NetBox IPAM System Deployed Successfully!"
echo "==========================================="

# Get the Tailscale IP if available
TAILSCALE_IP=""
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
fi

echo "📍 Access Points:"
echo "   Local HTTP:      http://localhost:8080"
echo "   Local HTTPS:     https://netbox.doofus.co"
echo "   Alternative:     https://ipam.doofus.co"
if [[ -n "$TAILSCALE_IP" ]]; then
    echo "   Tailscale:       http://$TAILSCALE_IP:8080"
fi

echo ""
echo "🔑 Credentials:"
echo "   Username:        $SUPERUSER_NAME"
echo "   Password:        (from .env file)"
echo "   API Token:       $NETBOX_API_TOKEN"

echo ""
echo "🤖 Automation Features:"
echo "   ✅ Network discovery runs every 30 minutes"
echo "   ✅ Auto-syncs to Technitium DNS"
echo "   ✅ Exports data hourly to /opt/netbox/discovery-scripts/exports/"
echo "   ✅ API available for further automation"

echo ""
echo "📚 Key API Endpoints:"
echo "   Sites:           https://netbox.doofus.co/api/dcim/sites/"
echo "   IP Addresses:    https://netbox.doofus.co/api/ipam/ip-addresses/"
echo "   Prefixes:        https://netbox.doofus.co/api/ipam/prefixes/"
echo "   Devices:         https://netbox.doofus.co/api/dcim/devices/"

echo ""
echo "🔧 Management Commands:"
echo "   View logs:       cd $NETBOX_DIR && docker compose logs -f"
echo "   Restart:         docker compose restart"
echo "   Stop:            docker compose down"
echo "   Backup:          ./scripts/backup-netbox.sh"

echo ""
echo "🚀 Next Steps:"
echo "   1. Access web interface and explore discovered networks"
echo "   2. Configure additional discovery networks if needed"
echo "   3. Set up webhooks for external integrations"
echo "   4. Create custom scripts for specific automation needs"
echo "   5. Configure backup procedures for long-term data retention"

echo ""
echo "💡 Pro Tips:"
echo "   - Discovery data is exported to JSON files every hour"
echo "   - Use the API to integrate with other homelab services"
echo "   - Set up monitoring alerts for discovery failures"
echo "   - Regular backups ensure network documentation is never lost"