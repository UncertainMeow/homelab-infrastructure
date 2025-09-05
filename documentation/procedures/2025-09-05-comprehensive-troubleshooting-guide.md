# Homelab Automation System - Comprehensive Troubleshooting Guide

**Date:** September 5, 2025  
**For:** Problem Resolution and System Recovery  
**Audience:** System Administrators  
**Emergency Reference:** Keep this handy for quick problem resolution  

## Emergency Quick Reference

**System Down? Start here:**

```bash
# 1. Check overall system health
./scripts/orchestrate-homelab-automation.sh status

# 2. Check critical services
docker compose ps                    # NetBox containers
systemctl status technitium         # DNS server
dig @10.203.1.3 google.com         # DNS functionality
curl -I http://localhost:8080       # NetBox web interface

# 3. Check logs for errors
docker compose logs --tail=50 netbox
journalctl -u technitium --lines=50
```

## System Health Diagnostics

### **Level 1: Quick Health Check**

```bash
#!/bin/bash
# Save as /opt/homelab-monitoring/health-check.sh

echo "🏥 Homelab Health Check - $(date)"
echo "========================================"

# DNS Server Check
if dig @10.203.1.3 google.com +time=3 +tries=1 >/dev/null 2>&1; then
    echo "✅ DNS Server: Operational"
else
    echo "❌ DNS Server: Failed"
    DNS_FAILED=true
fi

# NetBox API Check
if curl -s -f "http://localhost:8080/api/" >/dev/null 2>&1; then
    echo "✅ NetBox API: Operational"
else
    echo "❌ NetBox API: Failed"
    NETBOX_FAILED=true
fi

# Container Status Check
cd /opt/netbox
if docker compose ps | grep -q "Up"; then
    RUNNING=$(docker compose ps | grep "Up" | wc -l)
    TOTAL=$(docker compose ps | wc -l)
    echo "✅ Containers: $RUNNING/$TOTAL running"
else
    echo "❌ Containers: None running"
    CONTAINERS_FAILED=true
fi

# Network Connectivity Check
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet: Connected"
else
    echo "❌ Internet: Disconnected"
    INTERNET_FAILED=true
fi

# Disk Space Check
DISK_USAGE=$(df /opt | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -lt 90 ]]; then
    echo "✅ Disk Space: ${DISK_USAGE}% used"
else
    echo "⚠️ Disk Space: ${DISK_USAGE}% used (WARNING)"
fi

# Summary
if [[ -z "$DNS_FAILED" && -z "$NETBOX_FAILED" && -z "$CONTAINERS_FAILED" && -z "$INTERNET_FAILED" ]]; then
    echo ""
    echo "🎉 System Status: All systems operational"
    exit 0
else
    echo ""
    echo "⚠️ System Status: Issues detected - check specific components below"
    exit 1
fi
```

### **Level 2: Detailed Diagnostics**

```bash
#!/bin/bash
# Detailed system diagnostics

echo "🔍 Detailed System Diagnostics"
echo "==============================="

# Check system resources
echo "💾 System Resources:"
free -h
echo ""
df -h /opt
echo ""

# Check running processes
echo "🔄 Key Processes:"
ps aux | grep -E "(postgres|redis|python|caddy)" | grep -v grep
echo ""

# Check network connections
echo "🌐 Network Connections:"
netstat -tulpn | grep -E "(53|5380|8080|443)"
echo ""

# Check recent logs
echo "📋 Recent Log Activity:"
echo "NetBox logs (last 10 lines):"
docker compose logs --tail=10 netbox 2>/dev/null || echo "NetBox not running"

echo ""
echo "DNS server logs (last 10 lines):"
journalctl -u technitium --lines=10 --no-pager 2>/dev/null || echo "DNS logs not available"

echo ""
echo "Discovery logs (last 10 lines):"
tail -10 /opt/netbox/discovery-scripts/logs/discovery.log 2>/dev/null || echo "Discovery logs not available"
```

---

## Problem Categories and Solutions

## DNS Server Issues

### **Problem: DNS Server Not Responding**

**Symptoms:**
- `dig @10.203.1.3 google.com` times out
- Web services can't resolve domain names
- Orchestrator shows "DNS Server: ❌ Offline"

**Diagnosis Steps:**
```bash
# Check if Technitium service is running
systemctl status technitium

# Check if port 53 is listening
netstat -tulpn | grep :53

# Check DNS server logs
journalctl -u technitium --lines=50

# Test local DNS resolution
nslookup google.com 127.0.0.1
```

**Solutions:**

**Solution 1: Service Restart**
```bash
# Restart Technitium service
sudo systemctl restart technitium

# Wait 30 seconds
sleep 30

# Test DNS resolution
dig @10.203.1.3 google.com
```

**Solution 2: Port Conflict Resolution**
```bash
# Check what's using port 53
lsof -i :53

# If systemd-resolved is conflicting:
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Edit DNS configuration
sudo nano /etc/resolv.conf
# Add: nameserver 8.8.8.8

# Restart Technitium
sudo systemctl restart technitium
```

**Solution 3: Configuration Corruption**
```bash
# Restore from backup
sudo systemctl stop technitium
sudo cp /opt/backups/dns-config-backup.zip /opt/technitium/
cd /opt/technitium
sudo unzip -o dns-config-backup.zip
sudo systemctl start technitium
```

### **Problem: DNS Records Not Updating**

**Symptoms:**
- New services don't get DNS records
- `dig @10.203.1.3 new-service.doofus.co` returns NXDOMAIN
- Manual DNS sync fails

**Diagnosis Steps:**
```bash
# Check API connectivity
curl -I "http://10.203.1.3:5380/api/dashboard/stats/get"

# Verify API token
curl -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
     "http://10.203.1.3:5380/api/zones/list"

# Check zone existence
curl -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
     "http://10.203.1.3:5380/api/zones/records/get?zone=doofus.co"
```

**Solutions:**

**Solution 1: API Token Issue**
```bash
# Regenerate API token in Technitium web interface
# Go to: Administration → Sessions → Create Token
# Update environment variable:
export TECHNITIUM_API_TOKEN="new_token"
echo 'export TECHNITIUM_API_TOKEN="new_token"' >> ~/.bashrc
```

**Solution 2: Zone Missing**
```bash
# Create missing zone
curl -X POST "http://10.203.1.3:5380/api/zones/create" \
     -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
     -d "zone=doofus.co&type=Primary"
```

**Solution 3: Manual DNS Sync**
```bash
# Force manual sync
./scripts/orchestrate-homelab-automation.sh sync

# Or direct DNS record creation
curl -X POST "http://10.203.1.3:5380/api/zones/records/add" \
     -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
     -d "zone=doofus.co&domain=service.doofus.co&type=A&ipAddress=10.203.3.100&ttl=300"
```

---

## NetBox Issues

### **Problem: NetBox Web Interface Not Accessible**

**Symptoms:**
- `http://localhost:8080` times out or shows error
- "Connection refused" or "502 Bad Gateway" errors
- Orchestrator shows "NetBox API: ❌ Failed"

**Diagnosis Steps:**
```bash
# Check container status
cd /opt/netbox
docker compose ps

# Check NetBox container logs
docker compose logs netbox --tail=50

# Check database connectivity
docker compose logs postgres --tail=20

# Test port accessibility
curl -I http://localhost:8080
telnet localhost 8080
```

**Solutions:**

**Solution 1: Container Restart**
```bash
cd /opt/netbox
docker compose restart netbox

# Wait for startup
sleep 60

# Check status
docker compose ps
curl -I http://localhost:8080
```

**Solution 2: Database Issues**
```bash
# Check PostgreSQL status
docker compose logs postgres

# If database corruption suspected:
docker compose stop netbox netbox-worker
docker compose restart postgres
sleep 30
docker compose up -d netbox netbox-worker
```

**Solution 3: Resource Exhaustion**
```bash
# Check resource usage
docker stats --no-stream

# If memory issues, increase limits in docker-compose.yml:
nano docker-compose.yml
# Find NetBox service and modify:
# deploy:
#   resources:
#     limits:
#       memory: 4G  # Increase from 2G

# Apply changes
docker compose up -d
```

**Solution 4: Complete Rebuild**
```bash
# Last resort - rebuild NetBox from backup
cd /opt/netbox
docker compose down

# Restore from backup
BACKUP_FILE="/opt/backups/homelab-backup-$(date -d yesterday +%Y%m%d).tar.gz"
tar -xzf "$BACKUP_FILE" -C /tmp/
cat /tmp/*/netbox-db.sql | docker compose exec -T postgres psql -U netbox netbox

# Restart services
docker compose up -d
```

### **Problem: Network Discovery Not Working**

**Symptoms:**
- New services not appearing in NetBox
- Discovery reports show zero hosts
- Discovery container constantly restarting

**Diagnosis Steps:**
```bash
# Check discovery container status
docker compose ps netbox-discovery

# Check discovery logs
docker compose logs netbox-discovery --tail=50

# Check discovery configuration
cat /opt/netbox/.env | grep DISCOVERY

# Test network connectivity from container
docker compose exec netbox-discovery ping 10.203.1.1
```

**Solutions:**

**Solution 1: Network Configuration Issues**
```bash
# Check discovery networks configuration
nano /opt/netbox/.env

# Ensure correct networks are specified:
DISCOVERY_NETWORKS=10.203.0.0/16,100.64.0.0/10

# Restart discovery service
docker compose restart netbox-discovery
```

**Solution 2: Permission Issues**
```bash
# Check container permissions for network scanning
docker compose exec netbox-discovery ip addr show

# If needed, run with host networking:
# Edit docker-compose.yml to add:
# network_mode: host
# to the netbox-discovery service
```

**Solution 3: Python Dependencies**
```bash
# Rebuild discovery container with dependencies
docker compose stop netbox-discovery
docker compose build netbox-discovery
docker compose up -d netbox-discovery
```

---

## SSL/Caddy Issues

### **Problem: SSL Certificates Not Working**

**Symptoms:**
- HTTPS sites show certificate errors
- "Certificate not trusted" warnings in browser
- Caddy logs show certificate acquisition failures

**Diagnosis Steps:**
```bash
# Check Caddy status
docker compose logs caddy --tail=30

# Test certificate status
openssl s_client -connect git.doofus.co:443 -servername git.doofus.co

# Check Cloudflare API connectivity
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Verify domain ownership
dig git.doofus.co
```

**Solutions:**

**Solution 1: Cloudflare API Issues**
```bash
# Verify and regenerate Cloudflare API token
# Go to Cloudflare Dashboard → My Profile → API Tokens
# Ensure token has Zone:Zone:Read and Zone:DNS:Edit permissions

# Update token in environment
nano /opt/netbox/.env
# Update: CLOUDFLARE_API_TOKEN=new_token

# Restart Caddy
docker compose restart netbox-caddy
```

**Solution 2: DNS Propagation Issues**
```bash
# Check DNS propagation
nslookup git.doofus.co 8.8.8.8

# If DNS not propagated, wait and retry
# Or force certificate renewal:
docker compose exec netbox-caddy caddy reload --config /etc/caddy/Caddyfile
```

**Solution 3: Rate Limiting**
```bash
# If Let's Encrypt rate limited, use staging for testing:
# Edit Caddyfile to add:
# {
#   acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
# }

# Test with staging, then remove for production
```

### **Problem: Services Not Accessible via HTTPS**

**Symptoms:**
- `curl https://service.doofus.co` fails
- "Connection refused" or "502 Bad Gateway"
- Caddy configuration seems correct

**Diagnosis Steps:**
```bash
# Check service is running
curl http://10.203.3.100:8080  # Direct service access

# Check Caddy configuration
cat /opt/caddy/Caddyfile

# Validate Caddy config syntax
caddy validate --config /opt/caddy/Caddyfile

# Check Caddy logs
docker compose logs caddy | grep -i error
```

**Solutions:**

**Solution 1: Service Connectivity**
```bash
# Verify service is accessible from Caddy container
docker compose exec netbox-caddy curl http://10.203.3.100:8080

# If fails, check network connectivity:
docker network ls
docker network inspect netbox_default
```

**Solution 2: Configuration Regeneration**
```bash
# Regenerate Caddy configuration
python3 scripts/caddy-service-manager.py --update

# Reload Caddy
docker compose exec netbox-caddy caddy reload --config /etc/caddy/Caddyfile
```

**Solution 3: Manual Service Addition**
```bash
# Add service manually to Caddy config
nano /opt/caddy/Caddyfile

# Add entry:
service.doofus.co {
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
    reverse_proxy 10.203.3.100:8080
}

# Reload configuration
caddy reload --config /opt/caddy/Caddyfile
```

---

## Integration Issues

### **Problem: Orchestrator Script Failures**

**Symptoms:**
- `orchestrate-homelab-automation.sh status` shows errors
- Sync operations fail partway through
- API integration timeouts

**Diagnosis Steps:**
```bash
# Check environment variables
env | grep -E "(NETBOX|TECHNITIUM|DNS)"

# Test individual API endpoints
curl -H "Authorization: Token $NETBOX_API_TOKEN" \
     "http://localhost:8080/api/" | jq .

curl -H "Authorization: Bearer $TECHNITIUM_API_TOKEN" \
     "http://10.203.1.3:5380/api/dashboard/stats/get"

# Check script permissions
ls -la scripts/orchestrate-homelab-automation.sh
```

**Solutions:**

**Solution 1: Environment Configuration**
```bash
# Reload environment variables
source ~/.bashrc

# Or set them temporarily:
export NETBOX_API_TOKEN="your_token"
export TECHNITIUM_API_TOKEN="your_token"
export DNS_SERVER="10.203.1.3"
export NETBOX_URL="http://localhost:8080"
```

**Solution 2: API Token Regeneration**
```bash
# Regenerate NetBox API token:
# Go to NetBox → Admin → Authentication and Authorization → Tokens
# Create new token, copy value

# Regenerate Technitium API token:
./scripts/configure-existing-technitium.sh

# Update environment variables
nano ~/.bashrc
```

**Solution 3: Network Connectivity**
```bash
# Check if services are accessible
curl -I http://localhost:8080
curl -I http://10.203.1.3:5380

# Check firewall rules
sudo ufw status
sudo iptables -L
```

### **Problem: Service Auto-Discovery Failures**

**Symptoms:**
- New services deployed but not discovered
- Discovery reports show services but no DNS records created
- Manual sync doesn't pick up new services

**Diagnosis Steps:**
```bash
# Check discovery configuration
cat /opt/netbox/.env | grep DISCOVERY

# Manual discovery test
python3 /opt/netbox/discovery-scripts/discovery-agent.py

# Check NetBox for discovered services
curl -H "Authorization: Token $NETBOX_API_TOKEN" \
     "http://localhost:8080/api/ipam/ip-addresses/" | jq .
```

**Solutions:**

**Solution 1: Network Scope Issues**
```bash
# Ensure discovery networks include your service subnets
nano /opt/netbox/.env

# Add missing networks:
DISCOVERY_NETWORKS=10.203.0.0/16,192.168.1.0/24,100.64.0.0/10

# Restart discovery
docker compose restart netbox-discovery
```

**Solution 2: Service Detection Issues**
```bash
# Check if service responds to discovery
nmap -p 80,8080,3000 10.203.3.100

# If service doesn't respond to common ports, add manually:
./scripts/orchestrate-homelab-automation.sh add service-name 10.203.3.100 8080 web
```

**Solution 3: Discovery Database Issues**
```bash
# Reset discovery database entries
# In NetBox, go to IPAM → IP Addresses
# Delete incorrect entries
# Force rediscovery:
./scripts/orchestrate-homelab-automation.sh sync
```

---

## Performance Issues

### **Problem: Slow DNS Resolution**

**Symptoms:**
- `dig @10.203.1.3 google.com` takes >2 seconds
- Web browsing feels slow
- High DNS query latency

**Diagnosis Steps:**
```bash
# Test DNS performance
time dig @10.203.1.3 google.com
time dig @8.8.8.8 google.com

# Check DNS server resources
top | grep -i technitium

# Check query statistics in Technitium web interface
# Go to Dashboard → Statistics
```

**Solutions:**

**Solution 1: Cache Optimization**
```bash
# Access Technitium web interface
# Go to Settings → Cache
# Increase maximum records to 20000
# Set cache prefetch trigger to 1 second
# Save settings and restart service
```

**Solution 2: Forwarder Issues**
```bash
# Test forwarder performance
dig @1.1.1.1 google.com
dig @9.9.9.9 google.com

# If slow, reconfigure forwarders in Technitium:
./scripts/configure-existing-technitium.sh
```

**Solution 3: Resource Allocation**
```bash
# If Technitium is resource-constrained:
# Check system resources
free -m
top

# Consider moving to dedicated VM with more resources
```

### **Problem: NetBox Performance Issues**

**Symptoms:**
- NetBox web interface loads slowly
- API requests timeout
- Database queries taking too long

**Diagnosis Steps:**
```bash
# Check container resources
docker stats netbox

# Check database performance
docker compose logs postgres | grep -i slow

# Check disk I/O
iostat -x 1 5
```

**Solutions:**

**Solution 1: Resource Scaling**
```bash
# Increase container resources
nano docker-compose.yml

# Modify NetBox service:
services:
  netbox:
    deploy:
      resources:
        limits:
          memory: 4G  # Increase from 2G
          cpus: '2.0'

# Apply changes
docker compose up -d
```

**Solution 2: Database Optimization**
```bash
# Optimize PostgreSQL
docker compose exec postgres psql -U netbox netbox -c "VACUUM ANALYZE;"
docker compose exec postgres psql -U netbox netbox -c "REINDEX DATABASE netbox;"
```

**Solution 3: Data Cleanup**
```bash
# Clean old discovery data
find /opt/netbox/discovery-scripts/exports/ -name "*.json" -mtime +30 -delete

# Archive old NetBox data if needed
# In NetBox interface, review and remove outdated entries
```

---

## Disaster Recovery

### **Complete System Recovery**

**When everything is broken:**

**Step 1: Assess Damage**
```bash
# Check what's still working
docker ps
systemctl status technitium
df -h
ls -la /opt/backups/
```

**Step 2: Stop All Services**
```bash
cd /opt/netbox
docker compose down
sudo systemctl stop technitium
```

**Step 3: Restore from Backup**
```bash
# Find latest backup
ls -la /opt/backups/homelab-backup-*.tar.gz | tail -1

# Extract backup
LATEST_BACKUP=$(ls -t /opt/backups/homelab-backup-*.tar.gz | head -1)
mkdir -p /tmp/restore
tar -xzf "$LATEST_BACKUP" -C /tmp/restore

# Restore configurations
cp /tmp/restore/*/env /opt/netbox/.env
cp /tmp/restore/*/Caddyfile /opt/caddy/Caddyfile
```

**Step 4: Restore Services**
```bash
# Restore DNS
sudo systemctl start technitium
sleep 30

# Restore database
cd /opt/netbox
docker compose up -d postgres redis redis-cache
sleep 60
cat /tmp/restore/*/netbox-db.sql | docker exec -i netbox-postgres psql -U netbox netbox

# Restore NetBox
docker compose up -d
```

**Step 5: Validate Recovery**
```bash
# Test each component
dig @10.203.1.3 google.com
curl -I http://localhost:8080
./scripts/orchestrate-homelab-automation.sh status
```

### **Partial Recovery Scenarios**

**DNS Only Recovery:**
```bash
# If only DNS is broken:
sudo systemctl stop technitium
# Restore DNS config from backup
sudo systemctl start technitium
```

**NetBox Only Recovery:**
```bash
# If only NetBox is broken:
cd /opt/netbox
docker compose down
# Restore database from backup
docker compose up -d
```

---

## Prevention and Monitoring

### **Automated Health Monitoring**

```bash
# Create comprehensive monitoring script
cat > /opt/homelab-monitoring/system-monitor.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/homelab-monitor.log"
ALERT_EMAIL="admin@yourdomain.com"

# Function to send alerts (configure with your preferred method)
send_alert() {
    echo "$(date): ALERT: $1" >> "$LOG_FILE"
    # Add email/webhook notification here
}

# DNS Health Check
if ! dig @10.203.1.3 google.com +time=5 +tries=1 >/dev/null 2>&1; then
    send_alert "DNS server not responding"
fi

# NetBox Health Check
if ! curl -s -f http://localhost:8080/api/ >/dev/null 2>&1; then
    send_alert "NetBox API not accessible"
fi

# Disk Space Check
DISK_USAGE=$(df /opt | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 85 ]]; then
    send_alert "Disk usage high: ${DISK_USAGE}%"
fi

# Service Discovery Check
LAST_REPORT=$(find /opt/netbox/discovery-scripts/exports/ -name "*.json" -mmin -60 | wc -l)
if [[ $LAST_REPORT -eq 0 ]]; then
    send_alert "No recent discovery reports found"
fi
EOF

# Make executable and schedule
chmod +x /opt/homelab-monitoring/system-monitor.sh

# Run every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/homelab-monitoring/system-monitor.sh") | crontab -
```

### **Preventive Maintenance Schedule**

**Daily Automated:**
- Health monitoring checks
- Backup creation
- Log rotation

**Weekly Manual:**
- Review monitoring logs
- Check system resources
- Validate backup integrity

**Monthly Manual:**
- Update container images
- Review and clean old data
- Test disaster recovery procedures

---

## Getting Help

### **Log Collection for Support**

```bash
# Create support bundle
BUNDLE_DIR="/tmp/homelab-support-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BUNDLE_DIR"

# Collect system information
uname -a > "$BUNDLE_DIR/system-info.txt"
free -h > "$BUNDLE_DIR/memory-info.txt"
df -h > "$BUNDLE_DIR/disk-info.txt"

# Collect service status
./scripts/orchestrate-homelab-automation.sh status > "$BUNDLE_DIR/service-status.txt" 2>&1
docker compose ps > "$BUNDLE_DIR/container-status.txt"
systemctl status technitium > "$BUNDLE_DIR/dns-status.txt"

# Collect logs (sanitize sensitive data)
docker compose logs --tail=100 netbox > "$BUNDLE_DIR/netbox-logs.txt"
journalctl -u technitium --lines=100 --no-pager > "$BUNDLE_DIR/dns-logs.txt"
tail -100 /opt/netbox/discovery-scripts/logs/discovery.log > "$BUNDLE_DIR/discovery-logs.txt" 2>/dev/null

# Create archive
tar -czf "homelab-support-$(date +%Y%m%d-%H%M%S).tar.gz" -C /tmp "$BUNDLE_DIR"
echo "Support bundle created: homelab-support-$(date +%Y%m%d-%H%M%S).tar.gz"
```

### **Community Resources**

- **Documentation**: Reference this comprehensive guide
- **GitHub Issues**: Report bugs and request features
- **Configuration Examples**: Check the `configs/` directory
- **Script Library**: All automation scripts in `scripts/` directory

---

**Remember: Most issues can be resolved with a systematic approach:**

1. **Identify** the failing component
2. **Diagnose** using the provided commands
3. **Apply** the appropriate solution
4. **Validate** the fix worked
5. **Document** any custom solutions for future reference

**Keep this guide handy - it's your lifeline when things go wrong!** 🛠️