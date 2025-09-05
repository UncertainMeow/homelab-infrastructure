# Homelab Documentation Strategy & Implementation Plan

## Overview
This document outlines the comprehensive documentation strategy for homelab infrastructure, focusing on security, version control, and progressive publication workflows.

## Core Principles

### 1. Security-First Documentation
- **Secret Management**: All secrets managed via 1Password with references
- **Stateful Variables**: Environment-specific values clearly marked and templated
- **Progressive Exposure**: Private GitLab → Clean GitHub workflow

### 2. Ownership & Control
- **Data Portability**: All documentation in standard formats (Markdown, YAML, etc.)
- **Self-Hosted Primary**: BookStack/Outline/MkDocs for internal reference
- **Version Control**: Git for all changes and history
- **Emergency Access**: Direct file access always possible

### 3. Professional Presentation
- **Clean Documentation**: Well-formatted, searchable, navigable
- **Consistent Templates**: Standardized structure across all docs
- **Visual Appeal**: Professional appearance for reference and sharing

## Implementation Phases

### Phase 1: Private GitLab Setup (Priority)
**Purpose**: Safe experimentation and learning environment

**GitLab Installation**:
```bash
# Proxmox LXC container for GitLab
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/gitlab.sh)"
```

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
│   ├── raw/           # Actual configs with secrets
│   └── templates/     # Sanitized templates
├── scripts/
└── infrastructure-as-code/
    ├── terraform/
    ├── ansible/
    └── docker-compose/
```

### Phase 2: Documentation Website
**Technology Options** (in order of recommendation):

1. **MkDocs Material** 
   - Pros: Beautiful, fast, great search, Git-based
   - Cons: Python dependency
   
2. **BookStack**
   - Pros: User-friendly, hierarchical, good permissions
   - Cons: Database dependency, less portable
   
3. **Outline**
   - Pros: Modern interface, collaborative
   - Cons: More complex setup, Node.js

**Recommended**: Start with MkDocs Material for maximum portability

### Phase 3: Public GitHub Integration
**Workflow**:
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
  host: "{{ POSTGRES_HOST }}"           # Stateful, non-secret
  port: 5432                            # Standard, non-secret  
  username: "op://vault/item/username"  # 1Password reference
  password: "op://vault/item/password"  # 1Password reference
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
- **Platform**: {{ PLATFORM_TYPE }}
- **Host**: {{ HOST_IDENTIFIER }}
- **Version**: [Specific version]

## Security Analysis
[Security review of any third-party code]

## Implementation
[Step-by-step with templated values]

## Configuration Files
[Links to templates in /configs/templates/]

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

## GitLab Workflow

### Initial Setup Commands
```bash
# Clone private repo (after GitLab setup)
git clone https://gitlab.yourdomain.com/homelab/infrastructure.git
cd infrastructure

# Create branch for new work
git checkout -b feature/new-implementation

# Work and commit frequently
git add .
git commit -m "WIP: implementing feature"
git push origin feature/new-implementation

# Merge to main when ready
git checkout main
git merge feature/new-implementation
git push origin main
```

### Sanitization Process for GitHub
```bash
# Create sanitized branch
git checkout -b sanitized-for-github

# Run sanitization script (to be created)
./scripts/sanitize-for-public.sh

# Review changes
git diff main

# Push to GitHub remote
git remote add github https://github.com/yourusername/homelab-public.git
git push github sanitized-for-github:main
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

Before committing to GitLab (even private):
- [ ] Review for any personal domain names
- [ ] Check for any external IP addresses
- [ ] Verify no passwords or keys in plain text
- [ ] Confirm no personal identifying information

Before pushing to GitHub:
- [ ] Replace all templated variables
- [ ] Remove any specific hostnames
- [ ] Ensure all secrets use template format
- [ ] Test that documentation makes sense for general audience

## Self-Hosted Documentation Setup

### MkDocs Material Installation
```bash
# In Proxmox LXC or dedicated container
pip install mkdocs-material
pip install mkdocs-git-revision-date-localized-plugin

# Create docs structure
mkdocs new homelab-docs
cd homelab-docs

# Configure mkdocs.yml with Material theme
# Add Git integration for auto-updates from GitLab
```

### BookStack Alternative
```bash
# If preferring BookStack
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/bookstack.sh)"
```

## Next Steps

1. **Set up private GitLab instance**
2. **Create initial repository with this documentation**
3. **Implement Technitium documentation as first real example**
4. **Set up documentation website (MkDocs recommended)**
5. **Develop sanitization scripts for public publishing**
6. **Create templates for common infrastructure patterns**

## Tools for Future Development

### Secret Management
- **1Password CLI**: For automated secret injection
- **SOPS**: For encrypted secrets in Git
- **Ansible Vault**: For infrastructure automation secrets

### Documentation Generation
- **Terraform Docs**: Auto-generate infrastructure documentation
- **Ansible Docs**: Generate playbook documentation
- **Draw.io**: For network diagrams (can be stored as code)

## Success Metrics

- **Security**: No secrets ever committed to public repositories
- **Usability**: Can deploy from documentation alone
- **Maintainability**: Updates don't break existing documentation
- **Portability**: Can export all data in standard formats
- **Collaboration**: Others can contribute using public templates

---

*This strategy evolves with homelab growth and infrastructure maturity*