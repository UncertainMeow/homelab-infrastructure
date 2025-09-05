# Homelab Documentation Strategy & Implementation Plan

## Overview
This document outlines the comprehensive documentation strategy for homelab infrastructure, focusing on security, version control, and progressive publication workflows.

## Core Principles

### 1. Security-First Documentation
- **Secret Management**: All secrets managed via 1Password with references
- **Stateful Variables**: Environment-specific values clearly marked and templated
- **Progressive Exposure**: Private development → Clean public sharing workflow

### 2. Ownership & Control
- **Data Portability**: All documentation in standard formats (Markdown, YAML, etc.)
- **Self-Hosted Components**: MkDocs for internal reference, GitLab for future private hosting
- **Version Control**: Git for all changes and history
- **Emergency Access**: Direct file access always possible

### 3. Professional Presentation
- **Clean Documentation**: Well-formatted, searchable, navigable
- **Consistent Templates**: Standardized structure across all docs
- **Visual Appeal**: Professional appearance for reference and sharing

## Implementation Phases

### Phase 1: GitHub Repository Setup (Current)
**Purpose**: Immediate documentation hosting with professional presentation

**Repository Structure**:
```
homelab-infrastructure/
├── documentation/
│   ├── infrastructure/
│   │   ├── proxmox/
│   │   ├── networking/
│   │   └── dns/
│   ├── services/
│   ├── procedures/
│   └── templates/
├── configs/
│   ├── templates/     # Sanitized templates for public sharing
│   └── examples/      # Example configurations
├── scripts/           # Automation and utility scripts
└── docs/
    └── project-management/  # Handoff documents and project meta-files
```

**Benefits**:
- Immediate public sharing of sanitized documentation
- Professional presentation for community contribution
- Version control with full history
- Free hosting and collaboration features

### Phase 2: Self-Hosted Documentation Website
**Technology**: MkDocs Material in LXC Container

**Deployment Strategy**:
```bash
# Create Ubuntu LXC container
# Install Python and MkDocs Material
pip3 install mkdocs-material mkdocs-git-revision-date-localized-plugin

# Configure automatic Git synchronization
# Deploy with beautiful theme and search capabilities
```

**Features**:
- Beautiful, responsive documentation interface
- Automatic updates from Git repository
- Advanced search and navigation
- Dark/light theme support

### Phase 3: Private GitLab Integration (Future)
**Purpose**: Private development environment for sensitive configurations

**Deployment Options**:
1. **Docker in Ubuntu VM**: Most flexible, isolated approach
2. **Manual Installation**: Direct installation in LXC/VM
3. **Hosted Alternative**: Private repositories on GitHub/GitLab.com

**Workflow When Implemented**:
1. Develop and experiment in private GitLab
2. Sanitize and template sensitive information  
3. Push clean versions to public GitHub
4. Maintain templates for community contribution

## Template System Design

### Secret Management Pattern

#### For 1Password Integration:
```yaml
# Example service config
database:
  host: "__POSTGRES_HOST__"              # Stateful, non-secret
  port: 5432                             # Standard, non-secret  
  username: "op://vault/item/username"   # 1Password reference
  password: "op://vault/item/password"   # 1Password reference
```

#### For Manual Replacement:
```yaml
# Example service config  
database:
  host: "__POSTGRES_HOST__"       # Replace with actual host
  port: 5432                      # Standard port
  username: "__DB_USERNAME__"     # Replace with actual username
  password: "__DB_PASSWORD__"     # Replace with actual password
```

### Documentation Template Structure

Each major implementation should follow this structure:

```markdown
# [Service/Implementation Name]

## Quick Reference
- **Status**: [Active/Testing/Deprecated]
- **Dependencies**: [List dependencies]
- **Secrets Required**: [1Password vault references]
- **Stateful Variables**: [Environment-specific values]

## Overview
[What was implemented and why]

## Environment Details
- **Platform**: __PLATFORM_TYPE__
- **Host**: __HOST_IDENTIFIER__
- **Version**: [Specific version]

## Security Analysis
[Security review of any third-party code]

## Implementation
[Step-by-step with templated values]

## Configuration Files
[Links to templates in configs/templates/]

## Troubleshooting
[Common issues and solutions]

## Rollback Procedures
[How to undo changes]

## Maintenance
[Ongoing care requirements]
```

## File Naming Convention

```
YYYY-MM-DD-descriptive-name-with-dashes.md
2025-09-05-technitium-dns-dark-mode-implementation.md
```

## Current Workflow (GitHub-Based)

### Development Process
```bash
# Clone repository
git clone https://github.com/USERNAME/homelab-infrastructure.git
cd homelab-infrastructure

# Create branch for new work
git checkout -b feature/new-implementation

# Work and commit frequently
git add .
git commit -m "Implement: new feature with documentation"
git push origin feature/new-implementation

# Merge to main when ready
git checkout main
git merge feature/new-implementation
git push origin main
```

### Documentation Updates
```bash
# Use helper script for new documentation
./scripts/create-doc-template.sh service-name

# Edit the created template
# Commit changes with descriptive messages
git add documentation/services/YYYY-MM-DD-service-name-implementation.md
git commit -m "Document: service-name implementation with security review"
git push origin main
```

## Variable Replacement Guide

### Secret Categories

#### 1. Authentication Secrets
**Examples**: passwords, API keys, certificates  
**Format**: `op://vault/item/field` or `__SECRET_NAME__`

#### 2. Network Information
**Examples**: 
- Public IPs: **SECRET** - Use `__PUBLIC_IP__`
- Private IPs: **NOT SECRET** - Can include in public docs
- Domain names: **DEPENDS** - Personal domains are secrets

#### 3. System Identifiers
**Examples**:
- Hostnames: **SECRET** - Use `__HOSTNAME__`
- Container IDs: **NOT SECRET** - Generic examples OK
- Service ports: **NOT SECRET** - Standard ports OK

### Replacement Checklist

Before committing to public repository:
- [ ] Review for any personal domain names
- [ ] Check for any external IP addresses
- [ ] Verify no passwords or keys in plain text
- [ ] Confirm no personal identifying information
- [ ] Test that documentation makes sense for general audience

## Current Infrastructure Setup

### MkDocs Material Deployment
```bash
# In Proxmox LXC container
sudo apt update && sudo apt install -y python3-pip
pip3 install mkdocs-material mkdocs-git-revision-date-localized-plugin

# In repository directory
mkdocs serve --dev-addr 0.0.0.0:8000
# Access at http://CONTAINER_IP:8000
```

### GitLab Future Deployment
When ready to implement private GitLab:

**Option A: Docker in Ubuntu VM**
```bash
# Create Ubuntu VM with cloud-init template
# Install Docker
# Deploy GitLab container with persistent volumes
```

**Option B: Manual Installation**
```bash
# Create Ubuntu LXC container
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo EXTERNAL_URL="http://YOUR_IP" apt-get install gitlab-ee
```

## Tools for Development

### Secret Management
- **1Password CLI**: For automated secret injection
- **Template Variables**: Manual replacement system
- **Git Hooks**: Future automation for sanitization

### Documentation Generation
- **Helper Scripts**: Template creation and variable checking
- **MkDocs Material**: Beautiful documentation presentation
- **Git Integration**: Automatic updates and version control

## Success Metrics

- **Security**: No secrets in public repositories
- **Usability**: Can deploy from documentation alone
- **Maintainability**: Updates don't break existing documentation
- **Portability**: Can export all data in standard formats
- **Collaboration**: Others can contribute using public templates
- **Professional Appearance**: Documentation site looks polished and searchable

## Next Steps

1. **Complete MkDocs deployment** in LXC container
2. **Create Ubuntu VM template** for future GitLab deployment
3. **Implement next DNS feature** (DNS-over-HTTPS) using established documentation process
4. **Develop sanitization scripts** for automated template variable checking
5. **Plan GitLab deployment** when private repository hosting is needed

---

*This strategy evolves with homelab growth and infrastructure maturity. Current focus on GitHub-first approach with self-hosted components for enhanced functionality.*