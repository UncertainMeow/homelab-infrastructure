# Homelab Documentation Implementation Plan - Revised

## Phase 1: GitHub Repository Setup (Start Here)

### Step 1: Create GitHub Repository
```bash
# On your local machine or Proxmox host
mkdir ~/homelab-infrastructure
cd ~/homelab-infrastructure

# Initialize git
git init

# Create directory structure
mkdir -p {documentation/{infrastructure/{dns,proxmox,networking},services,procedures,templates},configs/{templates,examples},scripts}

# Create README
cat > README.md << 'EOF'
# Homelab Infrastructure Documentation

Comprehensive documentation for homelab infrastructure, focusing on DNS services, Proxmox virtualization, and service deployment.

## Repository Structure
- `documentation/` - All infrastructure documentation
- `configs/templates/` - Configuration templates and examples  
- `scripts/` - Automation and utility scripts

## Getting Started
- [Documentation Strategy](documentation/homelab-documentation-strategy.md)
- [Technitium DNS Dark Mode](documentation/infrastructure/dns/2025-09-05-technitium-dns-dark-mode-implementation.md)

## Current Focus
Building out encrypted DNS infrastructure with Technitium DNS Server, including:
- Dark mode interface implementation
- DNS-over-HTTPS configuration
- High availability setup across multiple nodes
- Ad blocking and split-horizon DNS

## Contributing
This repository follows security-first documentation practices with templated configurations for sensitive data.
EOF
```

### Step 2: Add Your Documentation Files
```bash
# Copy the sanitized documentation
cp /path/to/homelab_docs_strategy.md documentation/homelab-documentation-strategy.md
cp /path/to/technitium_sanitized_template.md documentation/infrastructure/dns/2025-09-05-technitium-dns-dark-mode-implementation.md

# Create the CSS template
mkdir -p configs/templates/technitium
cp /path/to/technitium_css_final.css configs/templates/technitium/main-dark.css

# Create project roadmap
cat > documentation/PROJECT_ROADMAP.md << 'EOF'
# Homelab Infrastructure Roadmap

## Current Phase: DNS Infrastructure Foundation

### Completed
- [x] Technitium DNS dark mode implementation
- [x] Documentation strategy and repository structure
- [x] Security review process for third-party code

### Next 30 Days
- [ ] Set up MkDocs documentation website
- [ ] Configure Technitium for DNS-over-HTTPS
- [ ] Implement popular ad blocking lists
- [ ] Document DNS zone configurations

### Medium Term (3-6 Months)  
- [ ] Deploy high availability DNS (3-5 instances)
- [ ] Implement infrastructure as code (Terraform/Ansible)
- [ ] Set up monitoring and alerting
- [ ] Create disaster recovery procedures

### Long Term Vision
- [ ] Complete DNS infrastructure with DNSSEC
- [ ] Full homelab service inventory and documentation
- [ ] Automated deployment and backup systems
- [ ] Community contribution templates

## Working with Future Assistance
Reference this roadmap and the documentation strategy when continuing this project.
EOF
```

### Step 3: Create Helper Scripts
```bash
# Documentation template generator
cat > scripts/create-doc-template.sh << 'EOF'
#!/bin/bash
# Create new documentation from template

if [ $# -eq 0 ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 nextcloud"
    exit 1
fi

SERVICE_NAME=$1
DATE=$(date +%Y-%m-%d)
FILENAME="documentation/services/${DATE}-${SERVICE_NAME}-implementation.md"

cat > "$FILENAME" << TEMPLATE
# ${SERVICE_NAME^} Implementation

## Quick Reference
- **Status**: [Planning/Testing/Active/Deprecated]
- **Dependencies**: []
- **Secrets Required**: []
- **Stateful Variables**: []

## Overview
[What is being implemented and why]

## Environment Details
- **Platform**: __PLATFORM__
- **Host**: __HOST_IP__:__PORT__
- **Version**: [specific version]

## Security Analysis
[Security review of any third-party components]

## Implementation Process
[Step-by-step implementation]

## Configuration Files
[Links to template files in configs/templates/]

## Troubleshooting
[Common issues and solutions]

## Rollback Procedures
[How to undo changes]

## Maintenance
[Ongoing maintenance requirements]

## Change Log
| Date | Version | Author | Changes |
|------|---------|--------|---------|
| ${DATE} | 1.0 | Homelab Admin | Initial implementation |
TEMPLATE

echo "Created template: $FILENAME"
echo "Edit the file and commit when ready"
EOF

chmod +x scripts/create-doc-template.sh

# Variable replacement helper
cat > scripts/prepare-for-deployment.sh << 'EOF'
#!/bin/bash
# Helper script for replacing template variables

echo "=== Template Variable Replacement Helper ==="
echo "This script helps identify variables that need replacement before deployment"
echo ""

if [ $# -eq 0 ]; then
    echo "Usage: $0 <template-file>"
    echo "Example: $0 configs/templates/technitium/main-dark.css"
    exit 1
fi

TEMPLATE_FILE=$1

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: File $TEMPLATE_FILE not found"
    exit 1
fi

echo "Variables found in $TEMPLATE_FILE:"
grep -o '__[A-Z_]*__' "$TEMPLATE_FILE" | sort | uniq

echo ""
echo "op:// references found:"
grep -o 'op://[^"]*' "$TEMPLATE_FILE" | sort | uniq

echo ""
echo "Remember to replace these before deployment!"
EOF

chmod +x scripts/prepare-for-deployment.sh
```

### Step 4: Initial Commit and Push to GitHub
```bash
# Add all files
git add .

# Initial commit
git commit -m "Initial homelab infrastructure documentation

- Add comprehensive documentation strategy
- Include Technitium DNS dark mode implementation
- Create template system for future services
- Establish security-first documentation practices
- Add helper scripts for template management

Ready for public sharing - all sensitive data templated"

# Create GitHub repository (do this on GitHub.com)
# Then connect and push:
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/homelab-infrastructure.git
git push -u origin main
```

## Phase 2: Documentation Website Setup

### Step 1: Deploy MkDocs Container
```bash
# Check if there's a community script for MkDocs or similar
# If not, create a simple container:

# Create Ubuntu LXC container, then:
sudo apt update && sudo apt install -y python3-pip
pip3 install mkdocs-material mkdocs-git-revision-date-localized-plugin

# In your repo directory:
cd ~/homelab-infrastructure

# Create MkDocs config
cat > mkdocs.yml << 'EOF'
site_name: Homelab Infrastructure Documentation
site_description: Comprehensive homelab infrastructure and services documentation
site_url: http://YOUR_DOCS_IP:8000

theme:
  name: material
  palette:
    - scheme: slate
      primary: blue
      accent: light blue
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
    - scheme: default
      primary: blue
      accent: light blue
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - search.highlight
    - content.code.copy

plugins:
  - search
  - git-revision-date-localized:
      type: date

nav:
  - Home: index.md
  - Strategy: documentation/homelab-documentation-strategy.md
  - Roadmap: documentation/PROJECT_ROADMAP.md
  - Infrastructure:
      - DNS: 
          - Technitium Dark Mode: documentation/infrastructure/dns/2025-09-05-technitium-dns-dark-mode-implementation.md
      - Proxmox: documentation/infrastructure/proxmox/
      - Networking: documentation/infrastructure/networking/
  - Services: documentation/services/
  - Templates: configs/templates/

markdown_extensions:
  - admonition
  - attr_list
  - codehilite:
      guess_lang: false
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences
  - toc:
      permalink: true
EOF

# Create index page
cat > index.md << 'EOF'
# Homelab Infrastructure Documentation

Welcome to the comprehensive documentation for homelab infrastructure and services.

## Current Focus: DNS Infrastructure

Building a robust, encrypted DNS infrastructure using Technitium DNS Server with:

- ✅ **Dark Mode Interface** - Eye-friendly administration interface
- 🔄 **DNS-over-HTTPS** - Encrypted DNS queries
- 🔄 **High Availability** - Multiple instances across nodes  
- 🔄 **Ad Blocking** - Popular block lists integration
- 🔄 **Split Horizon** - Internal vs external DNS resolution

## Quick Links

- [Documentation Strategy](documentation/homelab-documentation-strategy.md) - How this documentation works
- [Project Roadmap](documentation/PROJECT_ROADMAP.md) - Current and future plans
- [Technitium Dark Mode](documentation/infrastructure/dns/2025-09-05-technitium-dns-dark-mode-implementation.md) - Recent implementation

## Repository Structure

```
homelab-infrastructure/
├── documentation/          # All documentation files
│   ├── infrastructure/    # Core infrastructure (DNS, Proxmox, etc.)
│   ├── services/         # Application and service docs
│   └── procedures/       # Operational procedures
├── configs/
│   ├── templates/        # Configuration templates
│   └── examples/         # Example configurations
└── scripts/              # Automation and helper scripts
```

## Security & Best Practices

This documentation follows security-first practices:
- All sensitive data is templated with variables
- Third-party code undergoes security review
- Public repository safe for community sharing
- Template system for easy deployment

---

*Documentation updated automatically from Git repository*
EOF

# Start the development server
mkdocs serve --dev-addr 0.0.0.0:8000 &

echo "Documentation server running at http://YOUR_IP:8000"
```

## Phase 3: Continue DNS Infrastructure Development

### Next Implementation: DNS-over-HTTPS
With your documentation system now in place, proceed with:

1. **Research DNS-over-HTTPS setup** for Technitium
2. **Document the implementation** using your new template system
3. **Commit changes** to your GitHub repository
4. **Update MkDocs site** automatically

### Template for Next Documentation
```bash
# Use your new helper script:
./scripts/create-doc-template.sh technitium-dns-over-https

# This creates a new file following your established format
```

## Why This Approach Works

1. **Immediate Public Sharing** - Your documentation is already sanitized and ready
2. **Professional Presentation** - MkDocs gives you a beautiful documentation site
3. **Version Control** - Full Git history of all changes
4. **Scalable** - Easy to add new services and documentation
5. **Secure** - Template system prevents accidental secret exposure

## Success Verification

After setup, you should have:
- ✅ Public GitHub repository with professional documentation
- ✅ Self-hosted documentation website (MkDocs)
- ✅ Template system for future implementations
- ✅ Helper scripts for efficient documentation
- ✅ Clear roadmap for DNS infrastructure development

This foundation supports your entire DNS infrastructure project and scales to whatever services you add next.