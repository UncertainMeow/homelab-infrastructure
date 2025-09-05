# Complete Homelab Automation System - Deployment Guide

**Date:** September 5, 2025  
**Status:** ✅ Production Ready  
**Estimated Time:** 2-3 hours  
**Difficulty:** Intermediate  
**Prerequisites Review:** ✅ Required  

## Pre-Deployment Checklist

**Before starting, ensure you have:**

### **✅ System Requirements**
- [ ] Host system with Docker and Docker Compose installed
- [ ] Minimum 4GB RAM, 4 CPU cores, 50GB free storage
- [ ] Static IP addresses available for services
- [ ] Internet connectivity for downloads and certificates

### **✅ Accounts and Credentials**
- [ ] Tailscale account with auth key generated
- [ ] Cloudflare account with API token created
- [ ] Domain name registered and pointed to Cloudflare
- [ ] Admin email address for SSL certificates

### **✅ Network Information**
- [ ] Current DNS server IP (if you have Technitium running): `__DNS_SERVER_IP__`
- [ ] Network ranges to discover (e.g., `10.203.0.0/16`): `__DISCOVERY_NETWORKS__`
- [ ] Domain name for services (e.g., `doofus.co`): `__BASE_DOMAIN__`

### **✅ Security Preparation**
- [ ] Strong passwords generated for admin accounts
- [ ] API tokens ready to be created/configured
- [ ] SSH key access to target systems

---

## Phase 1: Foundation Setup (30 minutes)

### **Step 1.1: Repository Setup**

```bash
# Clone or verify repository location
cd ~/
git clone https://github.com/__YOUR_USERNAME__/homelab-infrastructure.git
cd homelab-infrastructure

# Verify file structure
ls -la
# Should show: configs/, scripts/, documentation/

# Make all scripts executable
chmod +x scripts/*.sh scripts/*.py
```

### **Step 1.2: Generate Secure Credentials**

Create secure random values for configuration:

```bash
# Generate all required random values
echo "=== SAVE THESE VALUES SECURELY ==="
echo ""
echo "# NetBox Configuration"
echo "SECRET_KEY=$(openssl rand -hex 25)"
echo "NETBOX_API_TOKEN=$(openssl rand -hex 20)" 
echo "POSTGRES_PASSWORD=$(openssl rand -base64 16)"
echo "REDIS_PASSWORD=$(openssl rand -base64 16)"
echo "REDIS_CACHE_PASSWORD=$(openssl rand -base64 16)"
echo ""
echo "# Admin Credentials"
echo "SUPERUSER_PASSWORD=$(openssl rand -base64 12)"
echo ""
echo "=== COPY THESE TO YOUR PASSWORD MANAGER ==="
```

**⚠️ CRITICAL: Save these values immediately in your password manager or secure note-taking system. You'll need them throughout deployment.**

### **Step 1.3: Environment Configuration**

Configure NetBox environment:

```bash
# Copy environment template
cp configs/netbox/.env.template configs/netbox/.env

# Edit configuration file
nano configs/netbox/.env
```

**Fill in ALL required variables using the values generated above:**

```bash
# NetBox Version
VERSION=v3.6

# PostgreSQL Database Configuration  
POSTGRES_DB=netbox
POSTGRES_USER=netbox
POSTGRES_PASSWORD=__PASTE_YOUR_POSTGRES_PASSWORD__

# Redis Configuration
REDIS_PASSWORD=__PASTE_YOUR_REDIS_PASSWORD__
REDIS_CACHE_PASSWORD=__PASTE_YOUR_REDIS_CACHE_PASSWORD__

# NetBox Configuration
SECRET_KEY=__PASTE_YOUR_SECRET_KEY__

# Superuser Configuration
SUPERUSER_NAME=admin
SUPERUSER_EMAIL=__YOUR_EMAIL_ADDRESS__
SUPERUSER_PASSWORD=__PASTE_YOUR_SUPERUSER_PASSWORD__
SUPERUSER_API_TOKEN=__PASTE_YOUR_NETBOX_API_TOKEN__

# Email Configuration (Optional - can leave blank)
EMAIL_SERVER=
EMAIL_USERNAME=
EMAIL_PASSWORD=

# Cloudflare for SSL (REQUIRED)
CLOUDFLARE_API_TOKEN=__YOUR_CLOUDFLARE_API_TOKEN__

# Network Discovery Configuration
DISCOVERY_NETWORKS=10.203.0.0/16,100.64.0.0/10
DNS_SERVER=10.203.1.3

# Integration APIs (Will be configured later)
TECHNITIUM_API_TOKEN=
TECHNITIUM_SERVER=10.203.1.3:5380
GITLAB_API_TOKEN=
GITLAB_SERVER=git.doofus.co
```

**Save the file (Ctrl+X, Y, Enter).**

---

## Phase 2: DNS Server Configuration (20 minutes)

### **Step 2.1: Configure Existing Technitium Server**

If you have Technitium DNS running at 10.203.1.3:

```bash
# Test current DNS server
dig @10.203.1.3 google.com

# If working, configure it:
./scripts/configure-existing-technitium.sh 10.203.1.3
```

**Follow the prompts:**
1. If no API token exists, provide admin username/password
2. Script will generate API token automatically
3. **SAVE THE API TOKEN** displayed at the end

### **Step 2.2: Verify DNS Configuration**

```bash
# Test basic DNS resolution
dig @10.203.1.3 google.com

# Test ad blocking (should return 0.0.0.0)
dig @10.203.1.3 doubleclick.net

# Test DNSSEC
dig @10.203.1.3 +dnssec cloudflare.com
```

**Expected Results:**
- ✅ Basic DNS resolution working
- ✅ Ad blocking active (returns 0.0.0.0 for blocked domains)
- ✅ DNSSEC validation enabled

### **Step 2.3: Update Environment with DNS Token**

```bash
# Edit NetBox environment file
nano configs/netbox/.env

# Add the API token generated in Step 2.1:
TECHNITIUM_API_TOKEN=__YOUR_GENERATED_TOKEN__
```

---

## Phase 3: NetBox IPAM Deployment (45 minutes)

### **Step 3.1: Deploy NetBox System**

```bash
# Deploy NetBox IPAM system
sudo ./scripts/deploy-netbox.sh
```

**Deployment Process:**
1. Script creates `/opt/netbox` directory
2. Copies configurations and starts containers
3. Initializes database and creates admin user
4. Starts network discovery service

**Watch for:**
- ✅ All containers start successfully
- ✅ Database initialization completes
- ✅ Web interface becomes accessible
- ✅ Network discovery begins

### **Step 3.2: Verify NetBox Access**

```bash
# Check container status
cd /opt/netbox
docker compose ps

# All services should show "Up" status
```

**Test web access:**
1. Open browser to: `http://localhost:8080` or `http://your-server-ip:8080`
2. Login with: `admin` / `your-superuser-password`
3. Verify NetBox interface loads correctly

### **Step 3.3: Configure Initial Data**

In NetBox web interface:

1. **Create Site:**
   - Go to Organization → Sites → Add
   - Name: `Homelab`
   - Status: `Active`
   - Save

2. **Create Prefixes:**
   - Go to IPAM → Prefixes → Add
   - Prefix: `10.203.0.0/16`
   - Site: `Homelab`
   - Status: `Active`
   - Save

3. **Verify Discovery:**
   - Go to IPAM → IP Addresses
   - Should see discovered devices appearing
   - Wait 5-10 minutes for initial discovery

---

## Phase 4: Service Integration (30 minutes)

### **Step 4.1: Configure Split-Horizon DNS**

```bash
# Set up intelligent DNS routing
export TECHNITIUM_API_TOKEN="your_token_from_step_2"
./scripts/dns-configure-split-horizon.sh
```

**This configures:**
- ✅ Split Horizon app installation in Technitium
- ✅ Smart routing for git.doofus.co and gitlab.doofus.co  
- ✅ Different IPs for LAN/Tailscale/Internet clients

### **Step 4.2: Test Split-Horizon Routing**

```bash
# Test DNS resolution - should return appropriate IP based on source
dig @10.203.1.3 git.doofus.co

# Expected results vary by network:
# From LAN: 10.203.3.126
# From Tailscale: 100.109.144.75  
# From Internet: 173.52.203.42
```

### **Step 4.3: Set Up Caddy Automation**

```bash
# Configure reverse proxy automation
export NETBOX_API_TOKEN="your_netbox_token"
export NETBOX_URL="http://localhost:8080"

# Generate initial Caddy configuration
python3 scripts/caddy-service-manager.py --update
```

**Verify Caddy Configuration:**
```bash
# Check generated configuration
cat /opt/caddy/Caddyfile

# Validate configuration syntax
caddy validate --config /opt/caddy/Caddyfile
```

---

## Phase 5: Automation Orchestration (15 minutes)

### **Step 5.1: Configure Master Orchestrator**

```bash
# Set up environment variables for orchestrator
export NETBOX_URL="http://localhost:8080"
export NETBOX_API_TOKEN="your_netbox_token"
export TECHNITIUM_API_TOKEN="your_technitium_token"
export DNS_SERVER="10.203.1.3"
```

**Make environment persistent:**
```bash
# Add to ~/.bashrc for permanent configuration
echo 'export NETBOX_URL="http://localhost:8080"' >> ~/.bashrc
echo 'export NETBOX_API_TOKEN="your_netbox_token"' >> ~/.bashrc  
echo 'export TECHNITIUM_API_TOKEN="your_technitium_token"' >> ~/.bashrc
echo 'export DNS_SERVER="10.203.1.3"' >> ~/.bashrc

# Reload environment
source ~/.bashrc
```

### **Step 5.2: Run Complete System Sync**

```bash
# Run full system synchronization
./scripts/orchestrate-homelab-automation.sh sync
```

**Expected Output:**
```
🔍 Running network discovery and synchronization...
🏥 Checking service health:
   NetBox: ✅ Online
   DNS Server: ✅ Online
📡 Triggering network discovery...
🌐 Syncing DNS records...
✅ Synced X DNS records
⚡ Updating Caddy configuration...
✅ Caddy configuration updated
✅ Discovery and sync completed
```

### **Step 5.3: Verify System Status**

```bash
# Check complete system health
./scripts/orchestrate-homelab-automation.sh status
```

**Expected Status Report:**
```
📊 Homelab Automation System Status
====================================

🌐 Core Services:
   NetBox IPAM: ✅ Online
   Technitium DNS: ✅ Online
   GitLab: ✅ Online

🔗 Integration Status:
   NetBox API: ✅ Configured
   DNS API: ✅ Configured
   Caddy Config: ✅ Present

📁 Data Exports:
   Discovery Reports: X files

🤖 Automation Features:
   ✅ Network discovery (every 30 minutes)
   ✅ DNS record synchronization
   ✅ Caddy configuration automation
   ✅ Data export to JSON files
   ✅ Service health monitoring
```

---

## Phase 6: Service Testing and Validation (20 minutes)

### **Step 6.1: Test Automatic Service Addition**

Add a test service to verify end-to-end automation:

```bash
# Add a test service
./scripts/orchestrate-homelab-automation.sh add test-service 10.203.3.99 8080 web
```

**Verify automation results:**
1. **NetBox**: Service appears in IP Addresses section
2. **DNS**: `dig @10.203.1.3 test-service.doofus.co` returns `10.203.3.99`
3. **Caddy**: Configuration updated with new service

### **Step 6.2: Test Web Access**

If you have services running:

```bash
# Test HTTPS access to configured services
curl -I https://git.doofus.co
curl -I https://netbox.doofus.co

# Expected: Valid SSL certificates and successful responses
```

### **Step 6.3: Validate Discovery Automation**

```bash
# Check discovery reports
ls -la /opt/netbox/discovery-scripts/exports/

# View latest discovery report
cat /opt/netbox/discovery-scripts/exports/discovery-report-*.json | jq .
```

**Expected Results:**
- ✅ JSON files with discovery data
- ✅ Network statistics and host information
- ✅ Service detection results

---

## Phase 7: Tailscale Integration (Optional, 10 minutes)

### **Step 7.1: Configure Tailscale DNS**

1. **Access Tailscale Admin Console:** https://login.tailscale.com/admin/dns
2. **Add Custom Nameserver:** 
   - IP: `10.203.1.3` (your DNS server)
   - Name: `Homelab DNS`
3. **Configure Split DNS:**
   - Search domain: `doofus.co`
   - Nameserver: `10.203.1.3`
4. **Enable Override:** Check "Override local DNS servers"

### **Step 7.2: Test Tailscale Routing**

From a Tailscale-connected device:

```bash
# Should resolve to Tailscale IP
nslookup git.doofus.co

# Expected result: Different IP than LAN clients get
```

---

## Post-Deployment Configuration

### **Step P.1: Schedule Automation Tasks**

Set up cron jobs for regular maintenance:

```bash
# Edit crontab
crontab -e

# Add these lines:
# Run discovery sync every hour
0 * * * * /path/to/homelab-infrastructure/scripts/orchestrate-homelab-automation.sh sync

# Update Caddy configuration every 4 hours  
0 */4 * * * python3 /path/to/homelab-infrastructure/scripts/caddy-service-manager.py --update

# Weekly health check report
0 6 * * 1 /path/to/homelab-infrastructure/scripts/orchestrate-homelab-automation.sh status > /var/log/homelab-health.log
```

### **Step P.2: Configure Monitoring**

Set up log monitoring:

```bash
# Create log directory
sudo mkdir -p /var/log/homelab-automation

# Monitor discovery logs
tail -f /opt/netbox/discovery-scripts/logs/discovery.log

# Monitor NetBox logs  
cd /opt/netbox && docker compose logs -f netbox
```

### **Step P.3: Document Your Specific Configuration**

Create a custom configuration document:

```bash
# Create your site-specific documentation
cat > documentation/procedures/your-homelab-config.md << 'EOF'
# Your Homelab Configuration

## Network Details
- DNS Server: 10.203.1.3
- NetBox Server: your-server-ip:8080
- Domain: doofus.co
- Discovery Networks: 10.203.0.0/16

## Credentials
- NetBox Admin: admin / [password in password manager]
- DNS Admin: admin / [password in password manager]

## API Tokens
- NetBox: [stored in environment]
- Technitium: [stored in environment]  
- Cloudflare: [stored in environment]

## Custom Services
[Document any custom services you add]

## Maintenance Schedule
[Document your backup and maintenance procedures]
EOF
```

---

## Troubleshooting Deployment Issues

### **Issue: NetBox Won't Start**

```bash
# Check container logs
cd /opt/netbox
docker compose logs netbox

# Common solutions:
# 1. Database connection issues - check PostgreSQL logs
docker compose logs postgres

# 2. Permission issues - fix ownership
sudo chown -R 1000:1000 netbox-media netbox-reports netbox-scripts

# 3. Environment variable issues - verify .env file
cat .env | grep -v '^#' | grep -v '^$'
```

### **Issue: DNS Server Not Responding**

```bash
# Check Technitium service status
systemctl status technitium

# Restart if needed
systemctl restart technitium

# Verify port availability
netstat -tulpn | grep :53
```

### **Issue: Discovery Not Working**

```bash
# Check discovery container logs
docker compose logs netbox-discovery

# Verify network connectivity
docker compose exec netbox-discovery ping 10.203.1.1

# Check NetBox API access
curl -H "Authorization: Token $NETBOX_API_TOKEN" \
     "http://localhost:8080/api/" | jq .
```

### **Issue: SSL Certificates Not Working**

```bash
# Check Cloudflare API token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Verify domain ownership in Cloudflare
# Check DNS propagation: https://whatsmydns.net/
```

---

## Deployment Validation Checklist

**Complete this checklist to confirm successful deployment:**

### **✅ Core Infrastructure**
- [ ] NetBox web interface accessible at http://localhost:8080
- [ ] Technitium DNS responding to queries on port 53
- [ ] PostgreSQL database running and accessible
- [ ] Redis caching services operational

### **✅ Network Discovery**
- [ ] Discovery service running and scanning networks
- [ ] New hosts appearing in NetBox IP Addresses section
- [ ] Discovery reports generating in exports directory
- [ ] Service detection identifying open ports correctly

### **✅ DNS Integration** 
- [ ] DNS records automatically created for discovered hosts
- [ ] Split-horizon routing working for git.doofus.co
- [ ] Ad blocking operational (doubleclick.net returns 0.0.0.0)
- [ ] DNSSEC validation enabled and working

### **✅ Reverse Proxy Automation**
- [ ] Caddy configuration generating automatically
- [ ] SSL certificates obtained via Cloudflare DNS challenge
- [ ] HTTPS access working for configured services
- [ ] Service health monitoring operational

### **✅ System Integration**
- [ ] Orchestrator script showing all services online
- [ ] API tokens configured and working
- [ ] Environment variables properly set
- [ ] Automation scripts executable and functional

### **✅ Operational Readiness**
- [ ] Backup procedures documented and tested
- [ ] Monitoring logs accessible and readable
- [ ] Troubleshooting procedures validated
- [ ] Maintenance tasks scheduled in cron

---

## Success! What You Now Have

**🎉 Congratulations! You've deployed an enterprise-grade homelab automation system.**

### **Immediate Benefits:**
- **Zero-touch service deployment** - New services automatically get DNS, SSL, and routing
- **Network-wide ad blocking** - 90%+ reduction in ads and tracking across all devices
- **Professional SSL certificates** - All services accessible via HTTPS automatically  
- **Complete network documentation** - Visual inventory of all network assets
- **API-driven automation** - Integrate with any external tools or scripts

### **Daily Operation:**
```bash
# Check system health
./scripts/orchestrate-homelab-automation.sh status

# Add new service
./scripts/orchestrate-homelab-automation.sh add service-name ip-address port type

# Force discovery sync
./scripts/orchestrate-homelab-automation.sh sync
```

### **Automatic Operations:**
- **Every 30 minutes**: Network discovery scans for new services
- **Every hour**: Discovery data exported to JSON files
- **Every 4 hours**: Caddy configuration refreshed
- **Daily**: Ad blocking lists updated automatically

**Your homelab is now enterprise-grade with Infrastructure as Code automation!** 🚀

---

**Next Steps:** Proceed to the [Operational User Guide](2025-09-05-operational-user-guide.md) to learn daily management procedures.