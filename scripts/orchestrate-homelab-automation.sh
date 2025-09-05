#!/bin/bash
# Homelab Automation Orchestrator
# Coordinates NetBox, Technitium DNS, and Caddy automation

set -e

echo "🎯 Homelab Automation Orchestrator"
echo "=================================="
echo "Integrating: NetBox ↔ DNS ↔ Caddy"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
NETBOX_URL="${NETBOX_URL:-http://localhost:8080}"
DNS_SERVER="${DNS_SERVER:-10.203.1.3}"
TECHNITIUM_API_TOKEN="${TECHNITIUM_API_TOKEN}"
NETBOX_API_TOKEN="${NETBOX_API_TOKEN}"

# Function to check service health
check_service() {
    local service_name="$1"
    local check_url="$2"
    
    echo -n "   $service_name: "
    if curl -s -f "$check_url" >/dev/null 2>&1; then
        echo "✅ Online"
        return 0
    else
        echo "❌ Offline"
        return 1
    fi
}

# Function to run discovery and sync
run_discovery_sync() {
    echo "🔍 Running network discovery and synchronization..."
    
    # Check if services are available
    echo "🏥 Checking service health:"
    
    netbox_ok=false
    dns_ok=false
    
    if check_service "NetBox" "$NETBOX_URL/api/"; then
        netbox_ok=true
    fi
    
    if check_service "DNS Server" "http://$DNS_SERVER:5380/api/dashboard/stats/get"; then
        dns_ok=true
    fi
    
    if [[ "$netbox_ok" = false ]] || [[ "$dns_ok" = false ]]; then
        echo "⚠️  Some services are offline. Proceeding with available services..."
    fi
    
    # Run network discovery (NetBox container handles this)
    echo "📡 Triggering network discovery..."
    if [[ "$netbox_ok" = true ]]; then
        # Discovery runs automatically, but we can trigger additional scan
        python3 "$SCRIPT_DIR/../configs/netbox/discovery-scripts/discovery-agent.py" &
        discovery_pid=$!
        echo "   Network discovery started (PID: $discovery_pid)"
    fi
    
    # Update DNS from NetBox data
    echo "🌐 Syncing DNS records..."
    if [[ "$netbox_ok" = true ]] && [[ "$dns_ok" = true ]]; then
        python3 - << 'EOF'
import os
import requests
import json

netbox_url = os.getenv('NETBOX_URL', 'http://localhost:8080')
netbox_token = os.getenv('NETBOX_API_TOKEN')
dns_server = os.getenv('DNS_SERVER', '10.203.1.3')
dns_token = os.getenv('TECHNITIUM_API_TOKEN')

if not netbox_token or not dns_token:
    print("⚠️  Missing API tokens, skipping DNS sync")
    exit(0)

headers = {'Authorization': f'Token {netbox_token}'}

# Get active IPs with DNS names from NetBox
response = requests.get(f"{netbox_url}/api/ipam/ip-addresses/", 
                       headers=headers, params={'status': 'active'})

if response.status_code == 200:
    ips = response.json()['results']
    synced = 0
    
    for ip_data in ips:
        if ip_data.get('dns_name'):
            hostname = ip_data['dns_name'].split('.')[0]
            ip = ip_data['address'].split('/')[0]
            
            # Add to DNS
            dns_data = {
                'zone': 'doofus.co',
                'domain': f"{hostname}.doofus.co", 
                'type': 'A',
                'ipAddress': ip,
                'ttl': 300
            }
            
            dns_response = requests.post(
                f"http://{dns_server}:5380/api/zones/records/add",
                headers={'Authorization': f'Bearer {dns_token}'},
                data=dns_data
            )
            
            if dns_response.status_code == 200:
                synced += 1
    
    print(f"✅ Synced {synced} DNS records")
else:
    print("❌ Failed to get IPs from NetBox")
EOF
    else
        echo "⚠️  Skipping DNS sync (services unavailable)"
    fi
    
    # Update Caddy configuration
    echo "⚡ Updating Caddy configuration..."
    if [[ "$netbox_ok" = true ]]; then
        if python3 "$SCRIPT_DIR/caddy-service-manager.py" --update; then
            echo "✅ Caddy configuration updated"
        else
            echo "⚠️  Caddy configuration update failed"
        fi
    else
        echo "⚠️  Skipping Caddy update (NetBox unavailable)"
    fi
    
    # Wait for discovery to complete
    if [[ -n "$discovery_pid" ]]; then
        echo "⏳ Waiting for discovery to complete..."
        wait $discovery_pid || true
    fi
    
    echo "✅ Discovery and sync completed"
}

# Function to show system status
show_status() {
    echo "📊 Homelab Automation System Status"
    echo "===================================="
    
    echo ""
    echo "🌐 Core Services:"
    check_service "NetBox IPAM" "$NETBOX_URL/api/"
    check_service "Technitium DNS" "http://$DNS_SERVER:5380/api/dashboard/stats/get"
    check_service "GitLab" "http://git.doofus.co"
    
    echo ""
    echo "🔗 Integration Status:"
    
    if [[ -n "$NETBOX_API_TOKEN" ]]; then
        echo "   NetBox API: ✅ Configured"
    else
        echo "   NetBox API: ❌ Missing token"
    fi
    
    if [[ -n "$TECHNITIUM_API_TOKEN" ]]; then
        echo "   DNS API: ✅ Configured"
    else
        echo "   DNS API: ❌ Missing token"
    fi
    
    # Check if Caddy is configured
    if [[ -f "/opt/caddy/Caddyfile" ]]; then
        echo "   Caddy Config: ✅ Present"
    else
        echo "   Caddy Config: ⚠️  Not found"
    fi
    
    echo ""
    echo "📁 Data Exports:"
    if [[ -d "/opt/netbox/discovery-scripts/exports" ]]; then
        export_count=$(ls -1 /opt/netbox/discovery-scripts/exports/*.json 2>/dev/null | wc -l)
        echo "   Discovery Reports: $export_count files"
    else
        echo "   Discovery Reports: ❌ Directory not found"
    fi
    
    echo ""
    echo "🤖 Automation Features:"
    echo "   ✅ Network discovery (every 30 minutes)"
    echo "   ✅ DNS record synchronization"
    echo "   ✅ Caddy configuration automation"
    echo "   ✅ Data export to JSON files"
    echo "   ✅ Service health monitoring"
}

# Function to add a new service
add_service() {
    local hostname="$1"
    local ip="$2"
    local port="${3:-80}"
    local service_type="${4:-web}"
    
    echo "➕ Adding new service: $hostname"
    echo "================================"
    
    # Add to NetBox (if available)
    if [[ -n "$NETBOX_API_TOKEN" ]]; then
        echo "📝 Adding to NetBox IPAM..."
        python3 - << EOF
import os
import requests
import json

netbox_url = os.getenv('NETBOX_URL', 'http://localhost:8080')
netbox_token = os.getenv('NETBOX_API_TOKEN')

headers = {'Authorization': f'Token {netbox_token}', 'Content-Type': 'application/json'}

ip_data = {
    'address': '$ip',
    'dns_name': '$hostname',
    'status': 'active',
    'description': 'Manually added service',
    'custom_fields': {
        'service_type': '$service_type',
        'service_port': $port
    }
}

response = requests.post(f"{netbox_url}/api/ipam/ip-addresses/", 
                        headers=headers, data=json.dumps(ip_data))

if response.status_code == 201:
    print(f"✅ Added {response.json()['address']} to NetBox")
else:
    print(f"⚠️ NetBox add failed: {response.text}")
EOF
    fi
    
    # Add to DNS
    if [[ -n "$TECHNITIUM_API_TOKEN" ]]; then
        echo "🌐 Adding DNS record..."
        curl -s -X POST "http://$DNS_SERVER:5380/api/zones/records/add" \
             -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
             -d "zone=doofus.co&domain=$hostname.doofus.co&type=A&ipAddress=$ip&ttl=300" >/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo "✅ DNS record added"
        else
            echo "⚠️  DNS add failed"
        fi
    fi
    
    # Add to Caddy
    echo "⚡ Adding to Caddy configuration..."
    if python3 "$SCRIPT_DIR/caddy-service-manager.py" --add "$hostname.doofus.co" "$ip" "$port" "$service_type"; then
        echo "✅ Caddy configuration updated"
    else
        echo "⚠️  Caddy update failed"
    fi
    
    echo "🎉 Service addition completed!"
}

# Main command handling
case "$1" in
    "status")
        show_status
        ;;
    "sync")
        run_discovery_sync
        ;;
    "add")
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 add <hostname> <ip> [port] [type]"
            echo "Example: $0 add grafana 10.203.3.100 3000 monitoring"
            exit 1
        fi
        add_service "$2" "$3" "$4" "$5"
        ;;
    "help"|"--help"|"-h")
        echo "Homelab Automation Orchestrator"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  status          Show system status and health"
        echo "  sync            Run discovery and sync all services"
        echo "  add <hostname> <ip> [port] [type]  Add new service"
        echo "  help            Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  NETBOX_URL              NetBox API URL (default: http://localhost:8080)"
        echo "  NETBOX_API_TOKEN        NetBox API token"
        echo "  TECHNITIUM_API_TOKEN    Technitium DNS API token"
        echo "  DNS_SERVER              DNS server IP (default: 10.203.1.3)"
        echo ""
        echo "Examples:"
        echo "  $0 status               # Check system health"
        echo "  $0 sync                 # Run full discovery sync"
        echo "  $0 add grafana 10.203.3.50 3000 monitoring"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac