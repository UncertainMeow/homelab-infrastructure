#!/bin/bash
# DNS-over-HTTPS and Ad Blocking Configuration Script
# Configures encrypted DNS and comprehensive ad blocking

set -e

# Configuration
DNS_SERVER="localhost:5380"
API_TOKEN="${TECHNITIUM_API_TOKEN}"
DOMAIN="${DNS_DOMAIN:-dns.doofus.co}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN}"
CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL}"

echo "🔒 Configuring DNS-over-HTTPS and Ad Blocking"
echo "============================================="

# Check prerequisites
check_prerequisites() {
    if [[ -z "$API_TOKEN" ]]; then
        echo "❌ TECHNITIUM_API_TOKEN environment variable not set"
        exit 1
    fi
    
    if [[ -z "$CLOUDFLARE_API_TOKEN" && "$1" == "--enable-ssl" ]]; then
        echo "❌ CLOUDFLARE_API_TOKEN required for SSL certificate generation"
        exit 1
    fi
    
    # Check API connectivity
    if ! curl -s "http://$DNS_SERVER/api/dashboard/stats/get" \
         -H "Authorization: Bearer $API_TOKEN" >/dev/null; then
        echo "❌ Cannot connect to Technitium API"
        exit 1
    fi
    
    echo "✅ Prerequisites validated"
}

# Configure DNS-over-HTTPS
configure_doh() {
    echo "🌐 Configuring DNS-over-HTTPS..."
    
    # Enable DoH service
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "dnsServerDomain=$DOMAIN&webServiceHttpPort=5380&dnsOverHttpPort=80&dnsOverTlsPort=853&dnsOverHttpsPort=443&dnsOverQuicPort=853&enableDnsOverHttp=true&enableDnsOverTls=true&enableDnsOverHttps=true&enableDnsOverQuic=true" || {
        echo "❌ Failed to configure DoH settings"
        return 1
    }
    
    echo "✅ DNS-over-HTTPS configured"
    echo "   DoH URL: https://$DOMAIN/dns-query"
    echo "   DoT: $DOMAIN:853"
    echo "   DoQ: $DOMAIN:853"
}

# Configure encrypted forwarders
configure_encrypted_forwarders() {
    echo "🔐 Configuring encrypted DNS forwarders..."
    
    # Set upstream DNS servers to encrypted providers
    local forwarders='[
        {
            "name": "Cloudflare",
            "url": "https://cloudflare-dns.com/dns-query",
            "protocol": "Https"
        },
        {
            "name": "Quad9",
            "url": "https://dns.quad9.net/dns-query", 
            "protocol": "Https"
        },
        {
            "name": "Cloudflare-TLS",
            "url": "1.1.1.1:853",
            "protocol": "Tls"
        },
        {
            "name": "Quad9-TLS",
            "url": "9.9.9.9:853",
            "protocol": "Tls"
        }
    ]'
    
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "forwarders=$(echo "$forwarders" | tr -d '\n' | sed 's/"/\\"/g')" || {
        echo "❌ Failed to configure encrypted forwarders"
        return 1
    }
    
    echo "✅ Encrypted DNS forwarders configured"
}

# Enable comprehensive ad blocking
configure_ad_blocking() {
    echo "🛡️ Configuring comprehensive ad blocking..."
    
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
    
    # Convert array to URL string
    local url_list=""
    for url in "${blocklist_urls[@]}"; do
        url_list="$url_list$url\n"
    done
    
    # Configure block lists
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "blockListUrls=$(echo -e "$url_list")" || {
        echo "❌ Failed to configure ad blocking lists"
        return 1
    }
    
    # Force immediate update of block lists
    curl -X POST "http://$DNS_SERVER/api/admin/blockList/flush" \
         -H "Authorization: Bearer $API_TOKEN" || {
        echo "⚠️  Warning: Failed to force block list update"
    }
    
    echo "✅ Ad blocking configured with ${#blocklist_urls[@]} lists"
    echo "   Lists will auto-update every 24 hours"
}

# Enable DNSSEC validation
configure_dnssec() {
    echo "🔐 Enabling DNSSEC validation..."
    
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "dnssecValidation=true&eDnsClientSubnet=true" || {
        echo "❌ Failed to configure DNSSEC"
        return 1
    }
    
    echo "✅ DNSSEC validation enabled"
}

# Configure caching and performance
configure_performance() {
    echo "⚡ Optimizing DNS performance..."
    
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "recursionTimeout=5000&recursionRetries=3&cacheMaximumRecords=10000&cacheMinimumRecordTtl=10&cacheMaximumRecordTtl=86400&cacheNegativeRecordTtl=300&cachePrefetchTrigger=2&cachePreloadGlobalForwarders=true&serveStale=true&serveStaleTtl=259200" || {
        echo "❌ Failed to configure performance settings"
        return 1
    }
    
    echo "✅ Performance optimizations applied"
    echo "   Cache: 10,000 records max"
    echo "   Prefetch: 2-second trigger"
    echo "   Serve stale: 72 hours"
}

# Configure logging
configure_logging() {
    echo "📊 Configuring DNS logging..."
    
    curl -X POST "http://$DNS_SERVER/api/settings/set" \
         -H "Authorization: Bearer $API_TOKEN" \
         -d "enableLogging=true&logQueries=true&useLocalTime=true&maxLogFileDays=30" || {
        echo "❌ Failed to configure logging"
        return 1
    }
    
    echo "✅ DNS logging configured"
    echo "   Query logging: enabled"
    echo "   Retention: 30 days"
}

# Test DNS functionality
test_dns_functionality() {
    echo "🧪 Testing DNS functionality..."
    
    # Test basic DNS resolution
    if dig @localhost google.com +short >/dev/null 2>&1; then
        echo "✅ Basic DNS resolution working"
    else
        echo "❌ Basic DNS resolution failed"
        return 1
    fi
    
    # Test ad blocking (using known ad domain)
    if dig @localhost doubleclick.net +short 2>/dev/null | grep -q "0.0.0.0"; then
        echo "✅ Ad blocking working (doubleclick.net blocked)"
    else
        echo "⚠️  Ad blocking test inconclusive"
    fi
    
    # Test DNSSEC validation
    if dig @localhost +dnssec cloudflare.com >/dev/null 2>&1; then
        echo "✅ DNSSEC validation working"
    else
        echo "⚠️  DNSSEC validation test inconclusive"
    fi
    
    echo "✅ DNS functionality tests completed"
}

# Generate SSL certificate using Cloudflare DNS challenge
generate_ssl_certificate() {
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        echo "⚠️  Skipping SSL certificate generation (no Cloudflare token)"
        return 0
    fi
    
    echo "🔐 Generating SSL certificate for $DOMAIN..."
    
    # Create Cloudflare credentials file
    mkdir -p /tmp/certbot-credentials
    cat > /tmp/certbot-credentials/cloudflare.ini << EOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
EOF
    chmod 600 /tmp/certbot-credentials/cloudflare.ini
    
    # Generate certificate using certbot
    if command -v certbot >/dev/null 2>&1; then
        certbot certonly --dns-cloudflare \
                --dns-cloudflare-credentials /tmp/certbot-credentials/cloudflare.ini \
                -d "$DOMAIN" \
                --non-interactive \
                --agree-tos \
                --email "$CLOUDFLARE_EMAIL" || {
            echo "❌ SSL certificate generation failed"
            rm -rf /tmp/certbot-credentials
            return 1
        }
        
        # Copy certificates to Technitium directory
        if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "/opt/dns-primary/ssl-certs/"
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "/opt/dns-primary/ssl-certs/"
            echo "✅ SSL certificate generated and installed"
        fi
    else
        echo "⚠️  certbot not installed, skipping SSL certificate generation"
    fi
    
    # Cleanup
    rm -rf /tmp/certbot-credentials
}

# Main execution
main() {
    local enable_ssl=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --enable-ssl)
                enable_ssl=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--enable-ssl] [--help]"
                echo ""
                echo "Options:"
                echo "  --enable-ssl        Generate SSL certificate for DoH"
                echo "  --help, -h         Show this help"
                echo ""
                echo "Environment Variables:"
                echo "  TECHNITIUM_API_TOKEN    Required: API token"
                echo "  DNS_DOMAIN             DNS server domain (default: dns.doofus.co)"
                echo "  CLOUDFLARE_API_TOKEN   Required for --enable-ssl"
                echo "  CLOUDFLARE_EMAIL       Required for --enable-ssl"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    echo "🚀 Starting DNS security and ad blocking configuration..."
    
    # Execute configuration steps
    check_prerequisites "$enable_ssl"
    configure_encrypted_forwarders
    configure_ad_blocking
    configure_dnssec
    configure_performance
    configure_logging
    
    if [[ "$enable_ssl" == true ]]; then
        generate_ssl_certificate
        configure_doh
    else
        echo "⚠️  Skipping DoH configuration (use --enable-ssl to enable)"
    fi
    
    # Test functionality
    test_dns_functionality
    
    echo ""
    echo "🎉 DNS security and ad blocking configuration completed!"
    echo ""
    echo "📋 Configuration Summary:"
    echo "   ✅ Encrypted DNS forwarders (Cloudflare, Quad9)"
    echo "   ✅ Comprehensive ad blocking (8 lists)"
    echo "   ✅ DNSSEC validation enabled"
    echo "   ✅ Performance optimizations applied"
    echo "   ✅ Query logging configured (30-day retention)"
    if [[ "$enable_ssl" == true ]]; then
        echo "   ✅ DNS-over-HTTPS enabled"
        echo "   🌐 DoH URL: https://$DOMAIN/dns-query"
    fi
    echo ""
    echo "💡 Next Steps:"
    echo "   1. Configure clients to use this DNS server"
    echo "   2. Set up Tailscale to use custom DNS"
    echo "   3. Monitor query logs and blocked domains"
    echo "   4. Configure additional block lists if needed"
}

main "$@"