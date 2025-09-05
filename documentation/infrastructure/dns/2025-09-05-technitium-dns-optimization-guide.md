# Technitium DNS Server Optimization Guide

**Target Server:** 10.203.1.3  
**Date:** September 5, 2025  
**Status:** Existing Helper-Scripts Installation - Ready for Optimization  

## Current Status Assessment

✅ **DNS Resolution Working**: Server responds on port 53  
✅ **EDNS Support**: Enhanced DNS functionality available  
⚠️ **Basic Configuration**: Minimal setup, needs security and performance optimization

## Priority Configuration Settings

Based on your homelab priorities, here's the **essential configuration breakdown**:

### 🔒 **SECURITY SETTINGS (Highest Priority)**

#### 1. DNS-over-HTTPS (DoH) Configuration
```
Navigate to: Settings → Optional Protocols
✅ Enable DNS-over-HTTPS (Port 443)
✅ Enable DNS-over-TLS (Port 853)  
✅ Enable DNS-over-QUIC (Port 853)

Certificate Requirements:
- Domain: dns.doofus.co
- SSL Certificate: Let's Encrypt via Cloudflare DNS challenge
```

#### 2. DNSSEC Validation
```
Settings → Security
✅ Enable DNSSEC Validation
✅ Enable EDNS Client Subnet
✅ DNSSEC Proof of Non-Existence: NSEC3
```

#### 3. Secure Forwarders (Encrypted Upstreams)
```
Settings → Forwarders → Add Forwarder
Primary:   https://cloudflare-dns.com/dns-query (DoH)
Secondary: https://dns.quad9.net/dns-query (DoH)
Tertiary:  1.1.1.1:853 (DoT)
Backup:    9.9.9.9:853 (DoT)

⚠️ Remove any unencrypted forwarders (8.8.8.8, etc.)
```

### 🛡️ **AD BLOCKING CONFIGURATION**

#### Block List URLs (Copy-paste these)
```
Settings → Blocking → Block List URLs

Essential Lists:
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://someonewhocares.org/hosts/zero/hosts
https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/BaseFilter/sections/adservers.txt
https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext

Advanced Protection:
https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt
https://raw.githubusercontent.com/AdguardTeam/AdguardFilters/master/TrackingFilter/sections/general_url.txt
https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt
https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser

Settings:
✅ Auto Update Block Lists: 24 hours
✅ Block List Next Update: Auto
```

### ⚡ **PERFORMANCE OPTIMIZATION**

#### Cache Settings
```
Settings → Cache
Maximum Records: 10000
Minimum Record TTL: 10 seconds
Maximum Record TTL: 86400 seconds (24 hours)
Negative Record TTL: 300 seconds (5 minutes)
✅ Enable Prefetch: 2 seconds trigger
✅ Enable Serve Stale: 259200 seconds (72 hours)
```

#### Recursion Settings  
```
Settings → Recursion
Timeout: 5000ms
Retries: 3
✅ Enable Recursion
✅ Allow Recursion Only For Private Networks: false (for Tailscale)
```

### 🌐 **SPLIT-HORIZON DNS SETUP**

#### Required Apps Installation
```
Apps → DNS App Store → Install:
1. Split Horizon
2. Geo Location  
3. Failover
4. Advanced Blocking (optional)
```

#### Split-Horizon Configuration for doofus.co
```
Zones → doofus.co → Add Record

Record Type: APP
Domain: git.doofus.co
App: Split Horizon
Class Path: SplitHorizon.SimpleAddress
Data: {"100.64.0.0/10":["100.109.144.75"],"10.203.0.0/16":["10.203.3.126"],"0.0.0.0/0":["173.52.203.42"]}

Repeat for:
- gitlab.doofus.co
- Any other services needing smart routing
```

### 📊 **LOGGING & MONITORING**

#### Query Logging
```
Settings → Logging
✅ Enable Logging
✅ Log Queries
✅ Use Local Time
Log Folder: /etc/dns/logs
Max Log File Days: 30
```

#### Statistics Configuration
```
Settings → Stats
✅ Enable Query Logs
✅ Enable Stats
Stats Type: Last Hour, Last Day, Last Week, Last Month
Max Stat File Days: 365
```

## 🤖 **AUTOMATION CONFIGURATION**

### API Access Setup
```
Administration → Sessions → Create Token
Token Name: homelab-automation
Permissions: 
✅ Administration
✅ DNS Client
✅ Zones
✅ Cache
✅ Blocking
✅ Settings

Save token securely for automation scripts
```

### Webhook Configuration (Optional)
```
Settings → General → Web Hook
URL: https://your-monitoring-system/webhook
Events: Zone Updated, Settings Changed, Service Started/Stopped
```

## 🚀 **IMMEDIATE ACTION STEPS**

### Step 1: Backup Current Configuration
```bash
# Access web interface: http://10.203.1.3:5380
# Settings → General → Backup Settings
# Download backup file before making changes
```

### Step 2: Apply Security Settings (Priority Order)
1. **Enable DoH/DoT** (requires SSL certificate)
2. **Configure encrypted forwarders**
3. **Enable DNSSEC validation**
4. **Set up comprehensive ad blocking**

### Step 3: Performance Optimization
1. **Optimize cache settings**
2. **Configure logging**
3. **Set up query statistics**

### Step 4: Split-Horizon Setup
1. **Install Split Horizon app**
2. **Create doofus.co zone**
3. **Add APP records for services**

## 🔧 **CONFIGURATION SCRIPTS**

I'll create automation scripts to apply these settings via API:

```bash
# Configure existing DNS server
./scripts/configure-existing-technitium.sh 10.203.1.3

# Enable security features
./scripts/enable-dns-security.sh 10.203.1.3

# Setup split-horizon for GitLab
./scripts/setup-split-horizon.sh 10.203.1.3
```

## ⚠️ **IMPORTANT WARNINGS**

### SSL Certificate Requirement
- DoH requires valid SSL certificate for dns.doofus.co
- Use Cloudflare DNS challenge to avoid port forwarding
- Certificate must be installed before enabling HTTPS protocols

### Network Impact
- Changes to forwarders may briefly interrupt DNS resolution
- Test configuration on non-critical times
- Keep backup of working configuration

### Tailscale Integration
- Ensure "Allow Recursion Only For Private Networks" is **disabled**
- Tailscale IPs (100.64.0.0/10) must be allowed for recursion
- Configure Tailscale to use 10.203.1.3 as custom nameserver

## 🧪 **TESTING CHECKLIST**

After configuration:

```bash
# Test basic DNS resolution
dig @10.203.1.3 google.com

# Test ad blocking  
dig @10.203.1.3 doubleclick.net  # Should return 0.0.0.0

# Test DoH (after SSL setup)
curl -H "Accept: application/dns-json" \
     "https://dns.doofus.co/dns-query?name=google.com&type=A"

# Test split-horizon
dig @10.203.1.3 git.doofus.co  # Should return different IPs based on source
```

## 📈 **EXPECTED IMPROVEMENTS**

After optimization:
- **Security**: 100% encrypted DNS queries
- **Ad Blocking**: 90%+ ads blocked network-wide  
- **Performance**: Sub-5ms local resolution
- **Reliability**: DNSSEC validation prevents spoofing
- **Smart Routing**: Correct IPs based on client location

---

**Next Step**: Apply these configurations systematically, starting with security settings!