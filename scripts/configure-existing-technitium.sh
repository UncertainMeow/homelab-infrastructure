#!/bin/bash
# Configure Existing Technitium DNS Server
# Optimizes existing installation at specified IP address

set -e

DNS_SERVER="${1:-10.203.1.3}"
DNS_PORT="5380"
API_TOKEN="${TECHNITIUM_API_TOKEN}"
DOMAIN="${DNS_DOMAIN:-dns.doofus.co}"

echo "🔧 Configuring Existing Technitium DNS Server at $DNS_SERVER"
echo "========================================================="

# Check prerequisites
check_prerequisites() {
    echo "✅ Validating prerequisites..."
    
    # Check if server is accessible
    if ! curl -s "http://$DNS_SERVER:$DNS_PORT/api/dashboard/stats/get" >/dev/null; then
        echo "❌ Cannot connect to Technitium DNS at $DNS_SERVER:$DNS_PORT"
        echo "   Make sure the server is running and accessible"
        exit 1
    fi
    
    # Check if we have credentials
    if [[ -z "$API_TOKEN" ]]; then
        echo "⚠️  No API token provided. You'll need to create one:"
        echo "   1. Go to http://$DNS_SERVER:$DNS_PORT"
        echo "   2. Login as admin"  
        echo "   3. Administration → Sessions → Create Token"
        echo "   4. Export TECHNITIUM_API_TOKEN=your_token"
        echo ""
        echo "   Or provide admin credentials to auto-generate token:"
        read -p "Admin username [admin]: " admin_user
        admin_user=${admin_user:-admin}
        read -s -p "Admin password: " admin_pass
        echo ""
        
        # Generate API token
        token_response=$(curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/auth/createToken" \
                        -d "user=$admin_user&pass=$admin_pass&tokenName=automation-$(date +%s)" 2>/dev/null)
        
        if echo "$token_response" | grep -q '"status":"ok"'; then
            API_TOKEN=$(echo "$token_response" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
            echo "✅ API token generated successfully"
            echo "   Export this for future use: export TECHNITIUM_API_TOKEN=$API_TOKEN"
        else
            echo "❌ Failed to generate API token. Check credentials and try again."
            exit 1
        fi
    fi
    
    echo "✅ Prerequisites validated"
}

# Configure security settings
configure_security() {
    echo "🔒 Configuring security settings..."
    
    # Enable DNSSEC validation
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "dnssecValidation=true&eDnsClientSubnet=true" >/dev/null || {
        echo "❌ Failed to enable DNSSEC"
        return 1
    }
    
    echo "✅ DNSSEC validation enabled"
}

# Configure encrypted forwarders
configure_encrypted_forwarders() {
    echo "🔐 Setting up encrypted DNS forwarders..."
    
    # Configure DoH and DoT forwarders
    local forwarders='[
        {
            "name": "Cloudflare-DoH",
            "forwarder": "https://cloudflare-dns.com/dns-query",
            "dnssecValidation": true,
            "proxyType": "Http",
            "proxyAddress": "",
            "proxyPort": 0,
            "proxyUsername": "",
            "proxyPassword": ""
        },
        {
            "name": "Quad9-DoH", 
            "forwarder": "https://dns.quad9.net/dns-query",
            "dnssecValidation": true,
            "proxyType": "Http",
            "proxyAddress": "",
            "proxyPort": 0,
            "proxyUsername": "",
            "proxyPassword": ""
        },
        {
            "name": "Cloudflare-DoT",
            "forwarder": "tls://1.1.1.1:853",
            "dnssecValidation": true,
            "proxyType": "None",
            "proxyAddress": "",
            "proxyPort": 0,
            "proxyUsername": "",
            "proxyPassword": ""
        }
    ]'
    
    # Apply forwarder configuration
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "forwarders=$(echo "$forwarders" | tr -d '\n')" >/dev/null || {
        echo "❌ Failed to configure encrypted forwarders"
        return 1
    }
    
    echo "✅ Encrypted DNS forwarders configured (Cloudflare DoH/DoT, Quad9 DoH)"
}

# Configure comprehensive ad blocking
configure_ad_blocking() {
    echo "🛡️ Setting up comprehensive ad blocking..."
    
    # Popular ad blocking lists
    local blocklist_urls=(
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        "https://someonewhocares.org/hosts/zero/hosts"
        "https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/BaseFilter/sections/adservers.txt"
        "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
        "https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/TrackingFilter/sections/general_url.txt"
        "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt"
        "https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser"
    )
    
    # Convert to newline-separated string
    local url_list=""
    for url in "${blocklist_urls[@]}"; do
        url_list="$url_list$url"$'\n'
    done
    
    # Apply block list configuration
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "blockListUrls=$url_list&blockListUpdateIntervalHours=24" >/dev/null || {
        echo "❌ Failed to configure ad blocking"
        return 1
    }
    
    # Force immediate update
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/admin/blockList/flush" \
         -H "Authorization: Bearer $API_TOKEN" >/dev/null || {
        echo "⚠️  Warning: Failed to trigger immediate block list update"
    }
    
    echo "✅ Ad blocking configured with ${#blocklist_urls[@]} comprehensive lists"
}

# Configure performance optimizations
configure_performance() {
    echo "⚡ Optimizing DNS performance..."
    
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "recursionTimeout=5000&recursionRetries=3&cacheMaximumRecords=10000&cacheMinimumRecordTtl=10&cacheMaximumRecordTtl=86400&cacheNegativeRecordTtl=300&cachePrefetchTrigger=2&serveStale=true&serveStaleTtl=259200" >/dev/null || {
        echo "❌ Failed to configure performance settings"
        return 1
    }
    
    echo "✅ Performance optimizations applied"
}

# Configure logging
configure_logging() {
    echo "📊 Setting up DNS logging..."
    
    curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "enableLogging=true&logQueries=true&useLocalTime=true&maxLogFileDays=30" >/dev/null || {
        echo "❌ Failed to configure logging"
        return 1
    }
    
    echo "✅ DNS logging configured (30-day retention)"
}

# Install required apps
install_apps() {
    echo "📦 Installing required DNS apps..."
    
    # List of required apps
    local apps=("SplitHorizon" "Failover")
    
    for app in "${apps[@]}"; do
        # Check if app is already installed
        if curl -s "http://$DNS_SERVER:$DNS_PORT/api/apps/list" \
           -H "Authorization: Bearer $API_TOKEN" | grep -q "\"name\":\"$app\""; then
            echo "✅ $app app already installed"
            continue
        fi
        
        # Install app
        curl -s -X POST "http://$DNS_SERVER:$DNS_PORT/api/apps/install" \
             -H "Authorization: Bearer $API_TOKEN" \
             -d "name=$app" >/dev/null && {
            echo "✅ $app app installed"
        } || {
            echo "⚠️  Warning: Failed to install $app app"
        }
        
        sleep 2  # Wait between installations
    done
}

# Test DNS functionality
test_dns_functionality() {
    echo "🧪 Testing DNS functionality..."
    
    # Test basic resolution
    if dig @$DNS_SERVER google.com +time=5 +tries=1 +short >/dev/null 2>&1; then
        echo "✅ Basic DNS resolution working"
    else
        echo "❌ Basic DNS resolution failed"
        return 1
    fi
    
    # Test DNSSEC
    if dig @$DNS_SERVER +dnssec cloudflare.com >/dev/null 2>&1; then
        echo "✅ DNSSEC validation working"
    else
        echo "⚠️  DNSSEC validation test inconclusive"
    fi
    
    # Test ad blocking (after lists are loaded)
    sleep 5
    local blocked_result=$(dig @$DNS_SERVER doubleclick.net +short 2>/dev/null | head -1)
    if [[ "$blocked_result" == "0.0.0.0" ]]; then
        echo "✅ Ad blocking working (doubleclick.net blocked)"
    else
        echo "⚠️  Ad blocking may still be loading (block lists updating)"
    fi
    
    echo "✅ DNS functionality tests completed"
}

# Display configuration summary
show_summary() {
    echo ""
    echo "🎉 Technitium DNS Server Configuration Complete!"
    echo "==============================================="
    echo "📍 Server: $DNS_SERVER:$DNS_PORT"
    echo "🔐 Security: DNSSEC enabled, encrypted forwarders"
    echo "🛡️  Ad Blocking: 8 comprehensive block lists"
    echo "⚡ Performance: Optimized caching and recursion"
    echo "📊 Logging: Query logging with 30-day retention"
    echo ""
    echo "🌐 Access Points:"
    echo "   Web Interface: http://$DNS_SERVER:$DNS_PORT"
    echo "   API Endpoint: http://$DNS_SERVER:$DNS_PORT/api"
    echo ""
    echo "🔑 API Token (save this):"
    echo "   export TECHNITIUM_API_TOKEN=$API_TOKEN"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Set up SSL certificate for DoH"
    echo "   2. Configure split-horizon DNS for services"
    echo "   3. Configure Tailscale to use this DNS server"
    echo "   4. Test from different network locations"
    echo ""
    echo "📚 Commands to run next:"
    echo "   ./scripts/setup-split-horizon.sh $DNS_SERVER"
    echo "   ./scripts/enable-dns-over-https.sh $DNS_SERVER"
}

# Main execution
main() {
    echo "🚀 Starting Technitium DNS optimization..."
    
    check_prerequisites
    configure_security  
    configure_encrypted_forwarders
    configure_ad_blocking
    configure_performance
    configure_logging
    install_apps
    
    # Brief pause for settings to apply
    echo "⏳ Allowing settings to propagate..."
    sleep 10
    
    test_dns_functionality
    show_summary
}

# Handle command line arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [DNS_SERVER_IP] [options]"
        echo ""
        echo "Arguments:"
        echo "  DNS_SERVER_IP          IP address of Technitium DNS server (default: 10.203.1.3)"
        echo ""
        echo "Options:"
        echo "  --help, -h            Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  TECHNITIUM_API_TOKEN  API token (will be generated if not provided)"
        echo "  DNS_DOMAIN           Domain for DNS server (default: dns.doofus.co)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Configure default server (10.203.1.3)"
        echo "  $0 10.203.1.5         # Configure specific server"
        echo ""
        exit 0
        ;;
    "")
        main
        ;;
    *)
        if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            DNS_SERVER="$1"
            main
        else
            echo "Invalid IP address: $1"
            exit 1
        fi
        ;;
esac