# Claude.md - Homelab DNS Infrastructure Project

## Project Context

The user is building a comprehensive DNS infrastructure for their homelab using Technitium DNS Server, with a focus on security, high availability, and encrypted DNS. This is part of a larger homelab documentation and infrastructure-as-code initiative.

## Current Status

### Completed Work
- **Technitium DNS Dark Mode Implementation**: Successfully implemented custom CSS dark theme with security review and troubleshooting
- **Documentation Strategy**: Established security-first documentation practices with template system for secrets management
- **Repository Structure**: Created sanitized documentation ready for public GitHub sharing
- **Project Foundation**: Clear roadmap and helper scripts for ongoing development

### Current Phase
User is transitioning to infrastructure deployment using:
- **Proxmox VE**: Primary hypervisor platform
- **Ubuntu Cloud-Init VMs**: For Docker-based services (GitLab)
- **LXC Containers**: For lightweight services (MkDocs)
- **Community Scripts**: Using helper-scripts.com for standardized deployments

## Technical Architecture

### Platform Strategy
- **Proxmox Host**: No direct Docker deployment (user preference)
- **VMs for Complex Services**: GitLab via Docker in Ubuntu VM
- **LXC for Simple Services**: MkDocs documentation site
- **Template-Based Deployment**: Using cloud-init for VM standardization

### DNS Infrastructure Goals
1. **Encrypted DNS**: DNS-over-HTTPS implementation
2. **High Availability**: 3-5 Technitium instances across nodes
3. **Ad Blocking**: Popular blocklist integration
4. **Split Horizon**: Internal vs external DNS resolution
5. **DNSSEC**: Future implementation for security

### Documentation System
- **Private Development**: Will establish GitLab for internal work
- **Public Sharing**: GitHub repository with sanitized templates
- **Documentation Site**: Self-hosted MkDocs Material
- **Secret Management**: 1Password integration planned

## Next Implementation Steps

### Immediate Priorities (Next Session)
1. **VM Template Creation**: Ubuntu cloud-init template using provided GitHub repository
2. **Docker Environment**: Configure Docker in VM template
3. **GitLab Deployment**: Docker-based GitLab for private repository hosting
4. **MkDocs Container**: LXC deployment for documentation website

### User's Planned Approach
- **VM Template Repository**: https://github.com/UncertainMeow/Ubuntu-CloudInit-Docs
- **GitLab via Docker**: Containerized deployment in VM
- **LXC for MkDocs**: Lightweight container deployment
- **No Docker on Host**: Maintains separation and security

## Key Technical Details

### Technitium DNS Configuration
- **Service Name**: `technitium.service`
- **File Paths**: `/opt/technitium/dns/www/`
- **Port**: 5380 (standard)
- **Dark Mode**: Successfully implemented and documented

### Documentation Standards
- **File Naming**: `YYYY-MM-DD-descriptive-name.md`
- **Template Variables**: Use `__VARIABLE_NAME__` format
- **Secret Management**: 1Password references `op://vault/item/field`
- **Security Review**: Required for all third-party code

### Infrastructure Preferences
- **Security-First**: No shortcuts on security practices
- **Documentation-Heavy**: Every change must be documented
- **Template-Based**: Reusable configurations for scaling
- **Version Controlled**: Git for all infrastructure and docs

## Important User Context

### Learning Approach
- **Documentation-Driven**: User wants comprehensive docs for all implementations
- **Security-Conscious**: Will not deploy without understanding security implications
- **Template-Oriented**: Prefers reusable, scalable solutions
- **Version Control**: Everything must be in Git with proper history

### Working Style
- **Methodical**: Prefers step-by-step implementation with troubleshooting
- **Forward-Thinking**: Plans for scaling and future requirements
- **Community-Minded**: Wants to share sanitized templates publicly

### Technical Constraints
- **Proxmox Environment**: Primary platform, familiar with LXC/VM deployment
- **No Direct Docker**: Prefers containerized approach within VMs/LXCs
- **Security Focus**: Will not compromise on security for convenience

## Files and Resources

### Documentation Assets
- `homelab_docs_strategy.md`: Comprehensive documentation strategy
- `technitium_sanitized_template.md`: Template for public sharing
- `technitium_css_final.css`: Working dark mode CSS
- Project roadmap and helper scripts established

### Next Implementation References
- Ubuntu Cloud-Init repository for VM template creation
- Community scripts for standardized deployments
- MkDocs Material for documentation website

## Handoff Instructions for Claude Code

### Primary Objectives
1. **Create Ubuntu VM template** using cloud-init methodology
2. **Deploy GitLab via Docker** in secure, documented manner
3. **Set up MkDocs documentation site** in LXC container
4. **Document everything** following established template system

### Critical Requirements
- **Security review** any third-party scripts or containers
- **Document each step** with troubleshooting and rollback procedures
- **Use template variables** for any environment-specific configuration
- **Test thoroughly** before considering implementation complete

### Success Criteria
- **Functional GitLab instance** accessible and configured
- **MkDocs site** displaying existing documentation beautifully
- **Complete documentation** for replicating the setup
- **Template configurations** ready for scaling/sharing

### User Expectations
- **Step-by-step guidance** with explanation of choices
- **Troubleshooting help** when issues arise
- **Security validation** of all implementations
- **Professional documentation** following established standards

The user values thorough, security-conscious implementation over speed. They want to understand what they're deploying and why, with the ability to maintain and scale the infrastructure independently.