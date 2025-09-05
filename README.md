# Homelab Automation Ecosystem

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)](#status)
[![Documentation](https://img.shields.io/badge/Documentation-Complete-blue)](#documentation)
[![Infrastructure as Code](https://img.shields.io/badge/Infrastructure-as%20Code-orange)](#automation)

**Transform your homelab from manual management to enterprise-grade Infrastructure as Code automation.**

This repository contains a complete homelab automation ecosystem that provides automatic service discovery, DNS management, reverse proxy configuration, and comprehensive network documentation - eliminating manual configuration for new service deployments.

---

## 🚀 What This System Does

### **Before: Manual Service Deployment** ❌
```bash
# Deploy new service
docker run -d --name grafana -p 3000:3000 grafana/grafana

# Then manually:
# 1. Add DNS record in Technitium
# 2. Configure reverse proxy in Caddy  
# 3. Update documentation
# 4. Remember IP assignments
# 5. Configure SSL certificates
# 6. Test from different networks
```

### **After: Zero-Touch Automation** ✅
```bash
# Deploy new service
docker run -d --name grafana -p 3000:3000 grafana/grafana

# Wait 30 minutes, or trigger discovery:
./scripts/orchestrate-homelab-automation.sh sync

# Service is now automatically:
# ✅ Discovered and documented in NetBox
# ✅ DNS record created (grafana.doofus.co)
# ✅ Reverse proxy configured with SSL
# ✅ Accessible via https://grafana.doofus.co
# ✅ Split-horizon routing configured
```

---

## 🏗️ System Architecture - Four Pillars

```mermaid
graph TB
    A[Network Discovery Agent] --> B[NetBox IPAM]
    B --> C[Technitium DNS Server]
    B --> D[Caddy Reverse Proxy]
    C --> D
    D --> E[Automated Service Access]
    E --> F[Zero-Touch New Services]
    
    G[Manual Service Addition] --> B
    H[API Integrations] --> B
    I[Webhook Automation] --> B
```

### 🔧 **Pillar 1: Enhanced DNS Infrastructure**
- **Service**: Technitium DNS Server (existing at 10.203.1.3)
- **Features**: DoH, DoT, DNSSEC, Ad Blocking, Split-Horizon DNS
- **Result**: Secure, encrypted DNS with intelligent routing

### 🌐 **Pillar 2: Network Documentation Hub**  
- **Service**: NetBox IPAM System
- **Features**: Auto-discovery, API automation, data export, visual mapping
- **Result**: Central source of truth for all network data

### ⚡ **Pillar 3: Reverse Proxy Automation**
- **Service**: Caddy Configuration Manager
- **Features**: Auto-SSL, service detection, configuration generation
- **Result**: Automatic HTTPS access for all discovered services

### 🎯 **Pillar 4: Integration Orchestration**
- **Service**: Automation Orchestrator
- **Features**: Health monitoring, sync management, service addition
- **Result**: Single interface for entire ecosystem management

---

## 📚 Documentation Guide

### **🚀 Getting Started (Start Here)**
| Document | Purpose | Audience |
|----------|---------|----------|
| **[Complete System Deployment Guide](documentation/procedures/2025-09-05-complete-system-deployment-guide.md)** | Step-by-step deployment instructions | All Users |
| **[System Overview](documentation/infrastructure/2025-09-05-complete-homelab-automation-ecosystem.md)** | Comprehensive architecture details | Technical Users |

### **📖 Operations & Maintenance**
| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[Operational User Guide](documentation/procedures/2025-09-05-operational-user-guide.md)** | Daily operations and management | Regular Operations |
| **[Troubleshooting Guide](documentation/procedures/2025-09-05-comprehensive-troubleshooting-guide.md)** | Problem diagnosis and solutions | When Issues Occur |

### **🔌 Development & Integration**
| Document | Purpose | Audience |
|----------|---------|----------|
| **[API Integration Guide](documentation/procedures/2025-09-05-api-integration-guide.md)** | Complete API reference and examples | Developers |
| **[Documentation Strategy](documentation/homelab-documentation-strategy.md)** | How documentation is structured | Contributors |

---

## 🎯 Quick Start

### **Option 1: Full Automated Deployment**
```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/homelab-infrastructure.git
cd homelab-infrastructure

# Run deployment (interactive setup)
./scripts/deploy-netbox.sh

# Configure existing DNS server
./scripts/configure-existing-technitium.sh

# Start automation
./scripts/orchestrate-homelab-automation.sh start
```

### **Option 2: Step-by-Step Deployment**
Follow the **[Complete System Deployment Guide](documentation/procedures/2025-09-05-complete-system-deployment-guide.md)** for detailed instructions.

### **Option 3: Component-by-Component**
1. **DNS Enhancement**: `./scripts/configure-existing-technitium.sh`
2. **NetBox IPAM**: `./scripts/deploy-netbox.sh`  
3. **Reverse Proxy**: `python3 scripts/caddy-service-manager.py --setup`
4. **Orchestration**: `./scripts/orchestrate-homelab-automation.sh sync`

---

## 📁 Repository Structure

```
homelab-infrastructure/
├── 📁 configs/                          # Configuration templates
│   ├── 📁 netbox/                       # NetBox IPAM system
│   │   ├── 📄 docker-compose.yml        # Main NetBox deployment
│   │   ├── 📄 .env.template              # Environment variables template
│   │   └── 📁 discovery-scripts/         # Network discovery automation
│   └── 📁 dns-primary/                   # Alternative DNS deployment
├── 📁 scripts/                           # Automation and deployment scripts
│   ├── 📄 configure-existing-technitium.sh    # DNS server optimization
│   ├── 📄 deploy-netbox.sh                   # NetBox IPAM deployment
│   ├── 📄 caddy-service-manager.py           # Reverse proxy automation
│   └── 📄 orchestrate-homelab-automation.sh  # Master orchestration
└── 📁 documentation/                     # Comprehensive documentation
    ├── 📁 infrastructure/               # Infrastructure component docs
    ├── 📁 procedures/                  # Operational procedures
    └── 📁 templates/                   # Documentation templates
```

---

## 🎛️ System Status

### **Production Components** ✅
- ✅ **DNS Infrastructure**: Enhanced Technitium server with DoH/DoT
- ✅ **NetBox IPAM**: Complete deployment package with discovery
- ✅ **Caddy Automation**: Full reverse proxy configuration management
- ✅ **Integration Orchestration**: Master automation control system
- ✅ **Documentation**: Complete deployment and operational guides

### **Success Metrics**
- **DNS Response Time**: <5ms local, <50ms remote
- **Service Discovery**: 95%+ accuracy rate  
- **Automation Success**: >90% zero-touch deployments
- **Uptime**: 99.9%+ availability across all components

---

## ⚡ Key Features

### **🔒 Security First**
- **Defense in Depth**: Multiple security layers across all components
- **Zero Trust Network**: All communication authenticated and encrypted
- **Secret Management**: Template system prevents credential exposure
- **Automated SSL**: Let's Encrypt certificates via Cloudflare DNS challenge

### **🚀 Automation Capabilities**
- **Network Discovery**: Automatic service detection every 30 minutes
- **DNS Management**: Split-horizon records for LAN/Tailscale/Internet
- **Reverse Proxy**: Auto-configured SSL termination and routing
- **Health Monitoring**: Continuous component health checks and recovery

### **📊 Enterprise Features**
- **IPAM Integration**: NetBox as central source of network truth
- **API-Driven**: Full REST API integration between all components
- **Webhook Support**: Event-driven automation triggers
- **Monitoring Ready**: Prometheus metrics and Grafana dashboards

---

## 🛠️ Requirements

### **Infrastructure Requirements**
- **Host System**: Proxmox VE, Ubuntu Server, or Docker host
- **Resources**: 4GB RAM, 4 CPU cores, 50GB storage minimum
- **Network**: Static IP addresses recommended

### **External Dependencies**
- **Tailscale Account**: For secure remote access
- **Cloudflare Account**: For DNS challenge SSL certificates  
- **Domain Name**: For SSL certificates and routing (e.g., doofus.co)

### **Software Dependencies**
- **Docker & Docker Compose**: Container orchestration
- **Python 3.8+**: For automation scripts
- **Curl**: For API interactions

---

## 🚨 Common Operations

### **Daily Operations**
```bash
# Check system health
./scripts/orchestrate-homelab-automation.sh status

# Trigger discovery sync  
./scripts/orchestrate-homelab-automation.sh sync

# View recent discoveries
./scripts/orchestrate-homelab-automation.sh report
```

### **Add New Service Manually**
```bash
# Add to NetBox via API
curl -X POST "http://netbox.local:8080/api/ipam/ip-addresses/" \
     -H "Authorization: Token __NETBOX_API_TOKEN__" \
     -d '{"address": "10.203.3.100", "dns_name": "service.doofus.co"}'

# Trigger automation
./scripts/orchestrate-homelab-automation.sh sync
```

### **Emergency Procedures**
```bash
# Stop all automation
./scripts/orchestrate-homelab-automation.sh stop

# Backup configuration
./scripts/orchestrate-homelab-automation.sh backup

# Restore from backup
./scripts/orchestrate-homelab-automation.sh restore backup-YYYYMMDD.tar.gz
```

---

## 🤝 Contributing

This repository follows security-first documentation practices:
- All sensitive data is templated with variables
- Third-party code undergoes security review
- Public repository safe for community sharing
- Template system for easy deployment

### **Adding New Services**
1. Use `./scripts/create-doc-template.sh service-name`
2. Follow established documentation patterns
3. Test with the validation scripts
4. Submit pull request with comprehensive documentation

---

## 🏆 What You Get

After successful deployment:
- ✅ **Network-wide ad blocking**: 90%+ ads blocked
- ✅ **Automatic service discovery**: New services found within 30 minutes  
- ✅ **DNS automation**: Records created automatically
- ✅ **SSL automation**: HTTPS access for all services
- ✅ **Documentation automation**: Network inventory always current
- ✅ **Split-horizon DNS**: Intelligent routing based on source network
- ✅ **Enterprise-grade infrastructure**: Production-ready automation

**Transform your homelab into Infrastructure as Code - deploy once, automate forever.**

---

*This automation ecosystem transforms homelab management from manual, error-prone processes into reliable, scalable Infrastructure as Code - providing enterprise-grade network automation for home environments.*
