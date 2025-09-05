# Security Hardening & Secrets Management Strategy

## 2. 🔐 **User Management & Automation Planning**

### Current State vs Future State
**Current (Root everywhere)** → **Future (Principle of Least Privilege)**

### Recommended User Architecture

#### Service Accounts Created by Templates
The Debian template creates these automation users automatically:

```bash
ansible    # For Ansible automation
terraform  # For Terraform deployments
```

Both users get:
- ✅ **Sudo access** with NOPASSWD (for automation)
- ✅ **SSH key authentication only**
- ✅ **Dedicated home directories**
- ✅ **Pre-configured workspace** (`/opt/ansible`, `/opt/terraform`)

#### SSH Key Strategy
```bash
# Generate dedicated keys for each service
ssh-keygen -t ed25519 -f ~/.ssh/ansible_homelab -C "ansible@homelab"
ssh-keygen -t ed25519 -f ~/.ssh/terraform_homelab -C "terraform@homelab"

# Deploy keys to VMs after creation:
ssh-copy-id -i ~/.ssh/ansible_homelab.pub ansible@vm-ip
ssh-copy-id -i ~/.ssh/terraform_homelab.pub terraform@vm-ip
```

#### Proxmox API Management
**Proxmox API User Setup:**
```bash
# Create API users in Proxmox
pveum user add ansible@pve
pveum user add terraform@pve

# Create roles with minimal required permissions
pveum role add AnsibleRole -privs "VM.Audit,VM.Clone,VM.Config.Disk,VM.Config.Memory,VM.Config.Network,VM.PowerMgmt"
pveum role add TerraformRole -privs "VM.Allocate,VM.Audit,VM.Clone,VM.Config.*,VM.PowerMgmt,Datastore.Audit"

# Assign roles to users
pveum aclmod / -user ansible@pve -role AnsibleRole
pveum aclmod / -user terraform@pve -role TerraformRole

# Generate API tokens
pveum user token add ansible@pve homelab-token --privsep 0
pveum user token add terraform@pve homelab-token --privsep 0
```

## 3. 🛡️ **Security Hardening Specifics**

### What "Security Hardened" Means in Our Context

#### SSH Hardening
```bash
# Applied automatically by template:
PermitRootLogin no              # No root SSH access
PasswordAuthentication no       # Key-based auth only
MaxAuthTries 3                 # Limit brute force attempts
ClientAliveInterval 300        # Timeout idle connections
AllowUsers ansible terraform   # Restrict user access
```

#### Firewall Configuration (UFW)
```bash
# Default deny incoming, allow outgoing
ufw default deny incoming
ufw default allow outgoing

# Allow SSH from private networks only
ufw allow from 192.168.0.0/16 to any port 22
ufw allow from 10.0.0.0/8 to any port 22
```

#### Intrusion Prevention (Fail2Ban)
```bash
# SSH monitoring with aggressive settings:
maxretry = 3          # Ban after 3 failed attempts
bantime = 3600        # 1 hour ban
findtime = 600        # 10 minute detection window
```

#### Kernel Security Parameters
```bash
# Container optimizations
vm.max_map_count=262144
fs.file-max=1000000

# Network security hardening
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
```

## 📦 **Secrets Management Strategy**

### Multi-Layer Secrets Architecture

#### Layer 1: 1Password (Personal/Development)
**Use for:** Development credentials, personal API keys, initial bootstrap

```bash
# 1Password CLI integration examples:
op item get "Proxmox API Token" --field credential
op item get "GitLab Root Token" --field password
```

#### Layer 2: Ansible Vault (Infrastructure Automation)
**Use for:** Ansible variables, service passwords, certificates

```yaml
# In group_vars/all/vault.yml (encrypted)
vault_proxmox_api_token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386434653...

vault_gitlab_root_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          33663735383...
```

#### Layer 3: HashiCorp Vault (Production/Advanced)
**Use for:** Dynamic secrets, PKI, advanced key rotation
**Future implementation** - start with 1Password + Ansible Vault

### Secrets Directory Structure
```
homelab-infrastructure/
├── secrets/
│   ├── .gitignore              # NEVER commit secrets
│   ├── 1password-refs.md       # Reference doc for 1Password items
│   └── ansible-vault/
│       ├── group_vars/
│       │   └── all/
│       │       └── vault.yml   # Encrypted Ansible secrets
│       └── host_vars/
└── configs/templates/
    ├── proxmox-api-token.j2    # Templates with {{ vault_var }} placeholders
    └── gitlab-config.j2
```

### Recommended Implementation Order

#### Phase 1: Bootstrap (Tonight)
1. **Use 1Password** for initial API tokens and passwords
2. **Store in environment variables** for script execution
3. **Document all secrets** in template format

#### Phase 2: Ansible Integration (Next Session)
1. **Create Ansible Vault** files for automation secrets
2. **Migrate from 1Password** to Vault for infrastructure
3. **Template all configurations** with vault variables

#### Phase 3: Production Hardening (Medium Term)
1. **Implement HashiCorp Vault** for dynamic secrets
2. **Set up secret rotation** policies
3. **Audit and compliance** logging

### Security Best Practices Applied

#### Secret Storage
- ❌ **Never in Git** - All secret files in .gitignore
- ✅ **Encrypted at rest** - Ansible Vault encryption
- ✅ **Least privilege** - Secrets only where needed
- ✅ **Audit trail** - All secret access logged

#### Secret Transmission
- ✅ **TLS everywhere** - All API calls over HTTPS
- ✅ **SSH agent forwarding** - No keys stored on remote hosts
- ✅ **Environment variables** - Temporary secret passing
- ✅ **Template substitution** - No hardcoded secrets in configs

#### Secret Rotation
- 🔄 **Regular rotation** - API tokens rotated quarterly
- 🔄 **Emergency rotation** - Compromised secrets rotated immediately
- 🔄 **Automated rotation** - HashiCorp Vault in future

### Directory Structure for API Keys & Secrets

```
# In your scripts directory:
configs/
├── api/
│   ├── proxmox/
│   │   ├── api-token.env.template    # Template with placeholder
│   │   └── .gitignore               # Ignore actual .env files
│   └── gitlab/
│       ├── admin-token.env.template
│       └── .gitignore

# Example template file:
# api-token.env.template
PROXMOX_HOST=__PROXMOX_HOST__
PROXMOX_USER=__PROXMOX_USER__
PROXMOX_TOKEN_ID=__PROXMOX_TOKEN_ID__
PROXMOX_SECRET=__PROXMOX_SECRET__

# Actual usage (not committed):
# api-token.env
PROXMOX_HOST=proxmox.homelab.local
PROXMOX_USER=terraform@pve
PROXMOX_TOKEN_ID=homelab-token
PROXMOX_SECRET=xxxx-xxxx-xxxx-xxxx
```

## 🚀 **Implementation Tonight**

### Immediate Actions
1. **Create service users** - Use Debian template with pre-configured users
2. **Generate SSH keys** - Separate keys for ansible/terraform
3. **Bootstrap with 1Password** - Use for initial API tokens
4. **Template everything** - No hardcoded secrets in any config

### Commands to Run Tonight
```bash
# Generate service SSH keys
ssh-keygen -t ed25519 -f ~/.ssh/ansible_homelab -C "ansible@homelab"
ssh-keygen -t ed25519 -f ~/.ssh/terraform_homelab -C "terraform@homelab"

# Create Proxmox API tokens (via web UI or CLI)
# Store in 1Password immediately

# Clone and configure first VM
qm clone 9001 201 --name gitlab-vm --full
qm set 201 --memory 4096 --cores 4
qm start 201

# Deploy SSH keys to new VM
ssh-copy-id -i ~/.ssh/ansible_homelab.pub ansible@<vm-ip>
```

This strategy gives you **production-grade security** while maintaining **automation compatibility**. You're moving from root-everywhere to proper service accounts, encrypted secrets, and audit trails - exactly what enterprises do.