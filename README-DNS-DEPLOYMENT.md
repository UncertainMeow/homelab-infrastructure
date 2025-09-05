# 🚀 DNS Infrastructure Deployment Guide

**Enterprise-Grade DNS Backbone for Homelab**

This guide walks you through deploying a production-ready DNS infrastructure using Technitium DNS Server with Tailscale integration, providing secure, encrypted DNS services with split-horizon routing.

## 🎯 What You'll Get

- **High-Availability DNS**: 99.9%+ uptime with failover capabilities
- **Encrypted DNS**: DNS-over-HTTPS, DNS-over-TLS, DNS-over-QUIC
- **Network-Wide Ad Blocking**: 90%+ ads blocked automatically
- **Smart Routing**: Different DNS responses for LAN/Tailscale/Internet clients
- **Full API Automation**: Infrastructure as Code for DNS management
- **Enterprise Security**: DNSSEC, monitoring, comprehensive logging

## 📋 Prerequisites

### System Requirements
- **Host**: Proxmox VM, Ubuntu Server, or Docker host
- **Resources**: 2GB RAM, 2 CPU cores, 20GB storage minimum
- **Network**: Static IP address recommended

### Required Accounts/Tokens
- **Tailscale account** with auth key
- **Cloudflare account** with API token (for SSL certificates)
- **Domain name** for DNS server (e.g., `dns.doofus.co`)

## 🚀 Quick Start (5 Minutes)

### Step 1: Clone Repository
```bash
git clone https://github.com/__USERNAME__/homelab-infrastructure.git
cd homelab-infrastructure
```

### Step 2: Configure Environment
```bash
# Copy environment template
cp configs/dns-primary/.env.template configs/dns-primary/.env

# Edit configuration (add your tokens and passwords)
nano configs/dns-primary/.env
```

Required variables:
```bash
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxxx
TECHNITIUM_ADMIN_PASSWORD=your_strong_password_here
CLOUDFLARE_API_TOKEN=your_cloudflare_token
CLOUDFLARE_EMAIL=your@email.com
```

### Step 3: Deploy Primary DNS Node
```bash
# Deploy DNS infrastructure
sudo ./scripts/dns-deploy-primary.sh
```

### Step 4: Configure DNS Services
```bash
# Enable DoH and ad blocking (with SSL)
sudo ./scripts/dns-enable-doh-adblocking.sh --enable-ssl

# Configure split-horizon DNS for GitLab
export TECHNITIUM_API_TOKEN="your_api_token"
./scripts/dns-configure-split-horizon.sh
```

### Step 5: Configure Tailscale DNS
1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/dns)
2. Add custom nameserver: `[Your DNS Node Tailscale IP]`
3. Add search domain: `doofus.co` → Custom nameserver
4. Enable "Override local DNS servers"

## 📖 Detailed Documentation

### 📁 File Structure
```
homelab-infrastructure/
├── configs/dns-primary/           # Primary DNS node configuration
│   ├── docker-compose.yml         # Container orchestration
│   ├── .env.template              # Environment variables template
│   └── monitoring/                # Prometheus monitoring
├── scripts/                       # Deployment and management scripts
│   ├── dns-deploy-primary.sh      # Deploy primary DNS node
│   ├── dns-enable-doh-adblocking.sh # Configure DoH and ad blocking
│   └── dns-configure-split-horizon.sh # Setup smart DNS routing
└── documentation/                 # Comprehensive documentation
    └── infrastructure/dns/
        └── 2025-09-05-technitium-dns-backbone-deployment.md
```

### 🔧 Configuration Files

#### Docker Compose Architecture
- **tailscale-dns**: Secure Tailscale network connectivity
- **technitium**: Main DNS server with web interface
- **dns-monitor**: Prometheus monitoring and health checks

#### Key Features Enabled
- **DNS Encryption**: DoH (443), DoT (853), DoQ (853)
- **Ad Blocking**: 8 comprehensive blocklists, auto-updated daily
- **DNSSEC**: Cryptographic validation of DNS responses
- **Smart Caching**: 10,000 record cache with prefetch
- **Query Logging**: 30-day retention with privacy controls

## 🌐 Split-Horizon DNS Configuration

### How It Works
Smart DNS routing provides different responses based on client location:

```
Client Location          Response
─────────────────────────────────────────
Tailscale Network    →   Tailscale IP
Local LAN           →   Local LAN IP  
Internet            →   Public IP
```

### Example Configuration
```bash
# GitLab service routing
git.doofus.co:
  - Tailscale clients: 100.109.144.75
  - LAN clients: 10.203.3.126
  - Internet clients: 173.52.203.42
```

## 🔒 Security Features

### Encryption
- **DNS-over-HTTPS**: Encrypted DNS via HTTPS (port 443)
- **DNS-over-TLS**: Encrypted DNS via TLS (port 853)
- **DNS-over-QUIC**: Latest encrypted DNS protocol

### Ad Blocking
Comprehensive protection using these lists:
- Steven Black's Hosts (ads + malware)
- SomeoneWho Cares (ads + tracking)
- AdGuard Base Filters
- Yoyo.org Ad Servers
- Windows Spy Blocker
- Coin Mining Protection

### DNSSEC Validation
Cryptographic verification prevents DNS spoofing and cache poisoning.

## 🔧 Management Commands

### Service Management
```bash
# View service status
cd /opt/dns-primary && docker compose ps

# View logs
docker compose logs -f technitium

# Restart services  
docker compose restart

# Stop services
docker compose down
```

### DNS Testing
```bash
# Test basic DNS resolution
dig @localhost google.com

# Test ad blocking
dig @localhost doubleclick.net  # Should return 0.0.0.0

# Test DoH
curl -H "Accept: application/dns-json" \
     "https://dns.doofus.co/dns-query?name=google.com&type=A"
```

### API Management
```bash
# Generate API token
curl -X POST "http://localhost:5380/api/auth/createToken" \
     -d "user=admin&pass=your_password&tokenName=automation"

# Add DNS record
curl -X POST "http://localhost:5380/api/zones/records/add" \
     -H "Authorization: Bearer your_token" \
     -d "zone=doofus.co&domain=new-service.doofus.co&type=A&ipAddress=10.203.3.100"

# List all zones
curl "http://localhost:5380/api/zones/list" \
     -H "Authorization: Bearer your_token"
```

## 📊 Monitoring and Health Checks

### Access Points
- **Web Interface**: `http://localhost:5380` (admin/your_password)
- **Tailscale Access**: `http://[tailscale-ip]:5380`
- **Prometheus Metrics**: `http://localhost:9090` (if enabled)

### Health Monitoring
```bash
# DNS health check
./scripts/dns-health-monitor.sh

# View query statistics
curl "http://localhost:5380/api/dashboard/stats/get" \
     -H "Authorization: Bearer your_token"

# Check blocked queries
curl "http://localhost:5380/api/dashboard/stats/getTop" \
     -H "Authorization: Bearer your_token" \
     -d "type=topBlockedDomains&statsType=LastHour"
```

## 🚀 Phase 2: High Availability (Next Steps)

### Secondary Node Deployment
1. Deploy second DNS node on different host
2. Configure keepalived for VIP failover
3. Set up automated backup synchronization
4. Enable health monitoring and alerting

### Commands for Phase 2
```bash
# Deploy secondary node
./scripts/dns-deploy-secondary.sh

# Configure HA cluster
./scripts/dns-configure-ha.sh

# Setup monitoring
./scripts/dns-setup-monitoring.sh
```

## 🔧 Troubleshooting

### Common Issues

#### DNS Service Won't Start
```bash
# Check port conflicts
netstat -tulpn | grep :53

# Check container logs
docker compose logs technitium

# Verify permissions
ls -la /opt/dns-primary/dns-config/
```

#### Tailscale Connection Issues
```bash
# Check Tailscale status
docker compose exec tailscale-dns tailscale status

# Restart Tailscale
docker compose restart tailscale-dns

# Re-authenticate if needed
docker compose exec tailscale-dns tailscale login
```

#### Split-Horizon Not Working
```bash
# Test DNS resolution from different networks
dig @localhost git.doofus.co

# Check Split Horizon app
curl "http://localhost:5380/api/apps/list" \
     -H "Authorization: Bearer your_token"

# Verify APP records
curl "http://localhost:5380/api/zones/records/get?zone=doofus.co" \
     -H "Authorization: Bearer your_token"
```

## 📚 Additional Resources

### Documentation
- [Technitium DNS Server Documentation](https://technitium.com/dns/help.html)
- [Tailscale DNS Configuration](https://tailscale.com/kb/1054/dns)
- [DNS-over-HTTPS Specification](https://tools.ietf.org/html/rfc8484)

### Community
- [Technitium GitHub](https://github.com/TechnitiumSoftware/DnsServer)
- [Tailscale Community](https://github.com/tailscale/tailscale)

## ⚠️ Security Considerations

### Best Practices
- Use strong passwords for admin accounts
- Regularly update containers and host OS
- Monitor DNS query logs for suspicious activity
- Backup DNS configurations regularly
- Use API tokens with limited scope

### Network Security
- Configure firewall rules appropriately
- Use Tailscale for secure remote access
- Enable DNSSEC validation
- Monitor for DNS amplification attacks

---

## 🎉 Success Metrics

After deployment, you should see:
- **DNS Response Time**: <5ms local, <50ms remote
- **Ad Blocking Rate**: 90%+ of ads and trackers blocked
- **Uptime**: 99.9%+ with proper monitoring
- **Query Encryption**: 100% of DNS queries encrypted
- **Split-Horizon**: Correct routing for all network contexts

**Your DNS backbone is now ready to support your entire homelab infrastructure!** 🚀