#!/bin/bash
# DNS Split-Horizon Configuration Script
# Configures smart DNS routing for GitLab and other services

set -e

# Configuration
DNS_SERVER="localhost:5380"
API_TOKEN="${TECHNITIUM_API_TOKEN}"
DOMAIN="doofus.co"

# Service IPs (will be populated from environment or parameters)
GITLAB_TAILSCALE_IP="${GITLAB_TAILSCALE_IP:-100.109.144.75}"
GITLAB_LAN_IP="${GITLAB_LAN_IP:-10.203.3.126}" 
PUBLIC_IP="${PUBLIC_IP:-173.52.203.42}"

echo "🌐 Configuring Split-Horizon DNS for GitLab Services"
echo "=================================================="

# Check if API token is set
if [[ -z "$API_TOKEN" ]]; then
    echo "❌ TECHNITIUM_API_TOKEN environment variable not set"
    echo "   Generate a token in Technitium Admin → Sessions → Create Token"
    exit 1
fi

# Function to check if API is accessible
check_api() {
    if ! curl -s "http://$DNS_SERVER/api/dashboard/stats/get" \
         -H "Authorization: Bearer $API_TOKEN" >/dev/null; then
        echo "❌ Cannot connect to Technitium API at $DNS_SERVER"
        echo "   Check if service is running and API token is valid"
        exit 1
    fi
}

# Function to install Split Horizon app if not already installed
install_split_horizon_app() {
    echo "📦 Installing Split Horizon app..."
    
    # Check if already installed
    if curl -s "http://$DNS_SERVER/api/apps/list" \
       -H "Authorization: Bearer $API_TOKEN" | grep -q "SplitHorizon"; then
        echo "✅ Split Horizon app already installed"
        return 0
    fi
    
    # Install from app store
    curl -X POST "http://$DNS_SERVER/api/apps/install" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "name=SplitHorizon" || {
        echo "❌ Failed to install Split Horizon app"
        exit 1
    }
    
    echo "✅ Split Horizon app installed successfully"
    sleep 5  # Wait for app to initialize
}

# Function to create zone if it doesn't exist
create_zone() {
    local zone=$1
    echo "🌍 Ensuring zone $zone exists..."
    
    # Check if zone exists
    if curl -s "http://$DNS_SERVER/api/zones/list" \
       -H "Authorization: Bearer $API_TOKEN" | grep -q "\"name\":\"$zone\""; then
        echo "✅ Zone $zone already exists"
        return 0
    fi
    
    # Create zone
    curl -X POST "http://$DNS_SERVER/api/zones/create" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "zone=$zone&type=Primary" || {
        echo "❌ Failed to create zone $zone"
        exit 1
    }
    
    echo "✅ Zone $zone created successfully"
}

# Function to add split-horizon record
add_split_horizon_record() {
    local subdomain=$1
    local zone=$2
    local tailscale_ip=$3
    local lan_ip=$4
    local public_ip=$5
    
    echo "📡 Adding split-horizon record for $subdomain.$zone"
    
    # Create JSON data for split horizon
    local json_data="{\"100.64.0.0/10\":[\"$tailscale_ip\"],\"10.203.0.0/16\":[\"$lan_ip\"],\"0.0.0.0/0\":[\"$public_ip\"]}"
    
    # Remove existing record if it exists
    curl -X POST "http://$DNS_SERVER/api/zones/records/delete" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "zone=$zone&domain=$subdomain.$zone&type=APP" 2>/dev/null || true
    
    # Add new APP record with split horizon
    curl -X POST "http://$DNS_SERVER/api/zones/records/add" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "zone=$zone&domain=$subdomain.$zone&type=APP&classPath=SplitHorizon.SimpleAddress&data=$(echo "$json_data" | sed 's/"/\\"/g')" || {
        echo "❌ Failed to add split-horizon record for $subdomain.$zone"
        return 1
    }
    
    echo "✅ Split-horizon record added for $subdomain.$zone"
    echo "   Tailscale (100.64.0.0/10): $tailscale_ip"
    echo "   LAN (10.203.0.0/16): $lan_ip"  
    echo "   Internet (0.0.0.0/0): $public_ip"
}

# Function to test DNS resolution
test_dns_resolution() {
    local domain=$1
    echo "🧪 Testing DNS resolution for $domain"
    
    # Test local resolution
    local result=$(dig @localhost "$domain" +short 2>/dev/null | head -1)
    if [[ -n "$result" ]]; then
        echo "✅ Local resolution: $domain → $result"
    else
        echo "❌ Failed to resolve $domain locally"
    fi
}

# Main execution
main() {
    echo "🚀 Starting split-horizon DNS configuration..."
    
    # Validate environment
    check_api
    
    # Install Split Horizon app
    install_split_horizon_app
    
    # Create domain zone
    create_zone "$DOMAIN"
    
    # Configure GitLab services
    echo "🦊 Configuring GitLab services..."
    add_split_horizon_record "git" "$DOMAIN" "$GITLAB_TAILSCALE_IP" "$GITLAB_LAN_IP" "$PUBLIC_IP"
    add_split_horizon_record "gitlab" "$DOMAIN" "$GITLAB_TAILSCALE_IP" "$GITLAB_LAN_IP" "$PUBLIC_IP"
    
    # Test DNS resolution
    echo ""
    echo "🧪 Testing DNS resolution..."
    test_dns_resolution "git.$DOMAIN"
    test_dns_resolution "gitlab.$DOMAIN"
    
    echo ""
    echo "🎉 Split-horizon DNS configuration completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "   Domain: $DOMAIN"
    echo "   GitLab services: git.$DOMAIN, gitlab.$DOMAIN"
    echo "   Tailscale clients: $GITLAB_TAILSCALE_IP"
    echo "   LAN clients: $GITLAB_LAN_IP"
    echo "   Internet clients: $PUBLIC_IP"
    echo ""
    echo "🔗 Access URLs:"
    echo "   From Tailscale: https://git.$DOMAIN"
    echo "   From LAN: https://git.$DOMAIN"
    echo "   From Internet: https://git.$DOMAIN"
    echo ""
    echo "💡 Tip: Test from different network contexts to verify split-horizon routing"
}

# Handle command line arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  TECHNITIUM_API_TOKEN    Required: API token for Technitium DNS"
        echo "  GITLAB_TAILSCALE_IP     GitLab Tailscale IP (default: 100.109.144.75)"
        echo "  GITLAB_LAN_IP          GitLab LAN IP (default: 10.203.3.126)"
        echo "  PUBLIC_IP              Public IP (default: 173.52.203.42)"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac