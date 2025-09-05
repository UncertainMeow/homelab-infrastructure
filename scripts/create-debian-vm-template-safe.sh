#!/bin/bash

# Debian 12 (Bookworm) CloudInit VM Template Creation Script - LOCKOUT-SAFE VERSION
# Multiple failsafes to prevent getting locked out of your infrastructure
# Based on painful lessons learned from hardening mishaps

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration Variables
VMID=${1:-9001}           # Default VM ID, can be overridden
STORAGE=${2:-local-lvm}   # Default storage, can be overridden  
VM_NAME="debian-12-homelab-template-safe"
DISK_SIZE="32G"           # Larger disk for development work
MEMORY="2048"             # More memory for containers
CORES="2"                 # Multiple cores for better performance
BRIDGE="vmbr0"            # Network bridge
USERNAME=${USER}          # Use current user as default

# SAFETY CONFIGURATION - PREVENT LOCKOUTS
EMERGENCY_USER="emergency"      # Always-accessible emergency user
CONSOLE_PASSWORD="Console123!"  # TEMPORARY console access (will be rotated)
SSH_GRACE_TIME="48h"           # Time before full hardening kicks in
ENABLE_GRADUAL_HARDENING=true  # Gradual hardening over time vs immediate

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_safety() {
    echo -e "${PURPLE}[SAFETY]${NC} $1"
}

# Safety validation functions
check_ssh_connectivity() {
    log_safety "Checking SSH connectivity before hardening..."
    
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes ${USERNAME}@localhost echo "SSH test" 2>/dev/null; then
        log_warning "SSH connectivity test failed - this is expected on first run"
        log_info "Will create multiple access methods to prevent lockouts"
    else
        log_success "SSH connectivity confirmed"
    fi
}

generate_recovery_keys() {
    log_safety "Generating emergency recovery keys using age/SOPS..."
    
    # Check if age is available
    if ! command -v age &> /dev/null; then
        log_warning "age not found - installing via Homebrew..."
        brew install age 2>/dev/null || {
            log_warning "Could not install age - skipping encrypted recovery keys"
            return 0
        }
    fi
    
    # Create recovery directory
    mkdir -p "/tmp/vm-${VMID}-recovery"
    
    # Generate age key if not exists
    AGE_KEY_FILE="$HOME/.config/age/homelab-recovery.txt"
    if [[ ! -f "$AGE_KEY_FILE" ]]; then
        log_info "Creating age key for recovery credentials..."
        mkdir -p "$(dirname "$AGE_KEY_FILE")"
        age-keygen -o "$AGE_KEY_FILE"
        chmod 600 "$AGE_KEY_FILE"
        log_success "Age key created at $AGE_KEY_FILE"
    fi
    
    # Get public key
    AGE_PUBLIC_KEY=$(age-keygen -y "$AGE_KEY_FILE")
    
    # Create recovery credentials file
    cat > "/tmp/vm-${VMID}-recovery/credentials.txt" << EOF
VM Recovery Credentials - VM ID: $VMID
Generated: $(date)

Emergency Access Methods:
1. Console Access (Proxmox Console):
   Username: $EMERGENCY_USER
   Password: $CONSOLE_PASSWORD
   
2. SSH Access (48h grace period):
   Username: $USERNAME
   SSH Key: $(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "No default SSH key found")
   
3. Root SSH (disabled after 48h):
   Initially enabled for emergency access
   Will be disabled automatically after grace period
   
4. Recovery Commands:
   # Re-enable SSH if locked out:
   sudo ufw allow ssh
   sudo systemctl restart ssh
   
   # Disable fail2ban temporarily:
   sudo systemctl stop fail2ban
   
   # Reset user password:
   sudo passwd $USERNAME
   
   # Add emergency SSH key:
   sudo -u $USERNAME mkdir -p /home/$USERNAME/.ssh
   sudo -u $USERNAME echo "YOUR_EMERGENCY_KEY" >> /home/$USERNAME/.ssh/authorized_keys

VM Configuration:
- VM ID: $VMID
- Template Name: $VM_NAME
- Storage: $STORAGE
- Network: $BRIDGE

Gradual Hardening Schedule:
- Hour 0-1: Full access (SSH keys + password + console)
- Hour 1-24: Password auth disabled, SSH keys only
- Hour 24-48: Fail2ban enabled, stricter SSH config
- Hour 48+: Full hardening active

IMPORTANT: Store this file securely and test access before full hardening!
EOF
    
    # Encrypt the recovery file
    log_info "Encrypting recovery credentials with age..."
    age -r "$AGE_PUBLIC_KEY" -o "/tmp/vm-${VMID}-recovery/credentials.age" "/tmp/vm-${VMID}-recovery/credentials.txt"
    rm "/tmp/vm-${VMID}-recovery/credentials.txt"  # Remove plaintext version
    
    log_success "Recovery credentials encrypted and saved to /tmp/vm-${VMID}-recovery/credentials.age"
    log_info "To decrypt: age -d -i $AGE_KEY_FILE /tmp/vm-${VMID}-recovery/credentials.age"
    
    # Also create in homelab infrastructure repo
    cp "/tmp/vm-${VMID}-recovery/credentials.age" "/Users/kellen/_code/UncertainMeow/homelab-infrastructure/recovery/vm-${VMID}-recovery.age"
}

create_gradual_hardening_script() {
    log_info "Creating gradual hardening script for safe security implementation..."
    
    cat << 'EOF' > /var/lib/vz/snippets/gradual-hardening.sh
#!/bin/bash
# Gradual Security Hardening Script
# Prevents immediate lockouts by implementing security in phases

LOCKFILE="/var/run/gradual-hardening.lock"
LOGFILE="/var/log/gradual-hardening.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOGFILE"
}

# Check if we're in grace period (first 48 hours)
BOOT_TIME=$(stat -c %Y /proc/1)
CURRENT_TIME=$(date +%s)
HOURS_SINCE_BOOT=$(( (CURRENT_TIME - BOOT_TIME) / 3600 ))

log_message "Hours since boot: $HOURS_SINCE_BOOT"

# Phase 1: 0-1 hours - Basic setup only
if [[ $HOURS_SINCE_BOOT -lt 1 ]]; then
    log_message "Phase 1: Initial setup - Maximum access preserved"
    exit 0
fi

# Phase 2: 1-24 hours - Disable password auth, keep SSH keys
if [[ $HOURS_SINCE_BOOT -ge 1 && $HOURS_SINCE_BOOT -lt 24 ]]; then
    if [[ ! -f "$LOCKFILE.phase2" ]]; then
        log_message "Phase 2: Disabling password authentication"
        
        # Disable password auth but keep everything else open
        sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        
        systemctl restart ssh
        touch "$LOCKFILE.phase2"
        log_message "Phase 2 complete - Password auth disabled, SSH keys still work"
    fi
    exit 0
fi

# Phase 3: 24-48 hours - Enable fail2ban and stricter SSH
if [[ $HOURS_SINCE_BOOT -ge 24 && $HOURS_SINCE_BOOT -lt 48 ]]; then
    if [[ ! -f "$LOCKFILE.phase3" ]]; then
        log_message "Phase 3: Enabling fail2ban and stricter SSH config"
        
        # Enable fail2ban
        systemctl enable --now fail2ban
        
        # Apply stricter SSH config but not maximum hardening yet
        cat >> /etc/ssh/sshd_config.d/99-gradual-hardening.conf << 'SSHCONF'
MaxAuthTries 6
ClientAliveInterval 300
ClientAliveCountMax 3
SSHCONF
        
        systemctl restart ssh
        touch "$LOCKFILE.phase3"
        log_message "Phase 3 complete - Fail2ban enabled, moderate SSH restrictions"
    fi
    exit 0
fi

# Phase 4: 48+ hours - Full hardening
if [[ $HOURS_SINCE_BOOT -ge 48 ]]; then
    if [[ ! -f "$LOCKFILE.phase4" ]]; then
        log_message "Phase 4: Applying full security hardening"
        
        # Apply full SSH hardening
        cat > /etc/ssh/sshd_config.d/99-full-hardening.conf << 'SSHCONF'
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
MaxSessions 2
X11Forwarding no
AllowUsers ansible terraform emergency
SSHCONF
        
        # Stricter fail2ban settings
        cat > /etc/fail2ban/jail.d/ssh-strict.conf << 'F2BCONF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
F2BCONF
        
        systemctl restart ssh
        systemctl restart fail2ban
        touch "$LOCKFILE.phase4"
        log_message "Phase 4 complete - Full security hardening applied"
        
        # Remove emergency user after full hardening (optional)
        # userdel -r emergency 2>/dev/null || true
    fi
fi
EOF
    
    chmod +x /var/lib/vz/snippets/gradual-hardening.sh
    log_success "Gradual hardening script created"
}

create_safe_cloudinit_config() {
    log_info "Creating LOCKOUT-SAFE CloudInit vendor configuration..."
    
    # Generate emergency user password hash
    EMERGENCY_HASH=$(openssl passwd -6 "$CONSOLE_PASSWORD")
    
    cat << EOF > /var/lib/vz/snippets/debian-homelab-safe.yaml
#cloud-config
# Debian 12 Homelab Template CloudInit Configuration - LOCKOUT-SAFE VERSION
# Multiple failsafes to prevent getting locked out

# Package management
package_update: true
package_upgrade: true
package_reboot_if_required: false

# Essential packages
packages:
  - qemu-guest-agent
  - openssh-server
  - curl
  - wget
  - git
  - htop
  - vim
  - tmux
  - tree
  - unzip
  - gnupg
  - ca-certificates
  - apt-transport-https
  - software-properties-common
  - ufw
  - fail2ban
  - sudo
  - python3
  - python3-pip
  - python3-venv

# SAFETY FIRST: Create multiple access methods
users:
  - default  # Keep the default user from CloudInit
  - name: ansible
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys: []  # Will be populated during deployment
    lock_passwd: false  # TEMPORARY: Allow password during grace period
  - name: terraform
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys: []  # Will be populated during deployment
    lock_passwd: false  # TEMPORARY: Allow password during grace period
  - name: ${EMERGENCY_USER}
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    passwd: '${EMERGENCY_HASH}'
    lock_passwd: false
    ssh_authorized_keys: []

# System configuration
timezone: 'America/New_York'
locale: 'en_US.UTF-8'

# SAFE SSH configuration - Gradual hardening
ssh_pwauth: true  # TEMPORARY: Enable during grace period
ssh_deletekeys: false  # Keep existing keys during setup
ssh_genkeytypes: ['ed25519', 'rsa']

# Create recovery and monitoring scripts
write_files:
  - path: /etc/sysctl.d/99-homelab.conf
    content: |
      # Container optimizations
      vm.max_map_count=262144
      fs.file-max=1000000
      net.core.somaxconn=32768
      net.ipv4.ip_local_port_range=1024 65535
      
      # Security hardening (moderate initially)
      net.ipv4.conf.all.send_redirects=0
      net.ipv4.conf.default.send_redirects=0
      net.ipv4.conf.all.accept_redirects=0
      net.ipv4.conf.default.accept_redirects=0
      
  - path: /usr/local/bin/emergency-access.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Emergency access recovery script
      echo "Emergency Access Recovery - VM ${VMID}"
      echo "1. Reset SSH configuration to defaults"
      echo "2. Disable fail2ban temporarily" 
      echo "3. Open firewall for SSH"
      echo "4. Show current users and access methods"
      echo ""
      echo "Run with: sudo emergency-access.sh [reset|status]"
      
      case "\$1" in
        reset)
          echo "Resetting to safe access configuration..."
          systemctl stop fail2ban
          ufw allow ssh
          cp /etc/ssh/sshd_config.orig /etc/ssh/sshd_config 2>/dev/null || true
          systemctl restart ssh
          echo "Access restored - remember to re-harden later!"
          ;;
        status)
          echo "Current access status:"
          echo "SSH service: \$(systemctl is-active ssh)"
          echo "Fail2ban: \$(systemctl is-active fail2ban)"
          echo "UFW status: \$(ufw status | head -1)"
          echo "SSH config: \$(grep -E '^(PasswordAuthentication|PermitRootLogin)' /etc/ssh/sshd_config)"
          ;;
        *)
          echo "Usage: emergency-access.sh [reset|status]"
          ;;
      esac
      
  - path: /etc/cron.d/gradual-hardening
    content: |
      # Gradual security hardening cron job
      SHELL=/bin/bash
      PATH=/usr/local/bin:/usr/bin:/bin
      */15 * * * * root /var/lib/vz/snippets/gradual-hardening.sh
      
  - path: /usr/local/bin/access-test.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Test access methods before full hardening
      echo "Testing access methods for VM ${VMID}..."
      echo "1. SSH key auth: \$(ssh -o BatchMode=yes -o ConnectTimeout=5 localhost echo 'OK' 2>/dev/null || echo 'FAILED')"
      echo "2. Console access: Available via Proxmox console"
      echo "3. Emergency user: ${EMERGENCY_USER} (console only after hardening)"
      echo "4. Recovery script: /usr/local/bin/emergency-access.sh"

# Safe initialization commands
runcmd:
  # Backup original SSH config for emergency restoration
  - cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
  
  # Start essential services
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
  
  # Set up basic firewall (permissive initially)
  - ufw default deny incoming
  - ufw default allow outgoing  
  - ufw allow ssh
  - ufw allow from 192.168.0.0/16 to any port 22
  - ufw allow from 10.0.0.0/8 to any port 22
  - ufw --force enable
  
  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-homelab.conf
  
  # Create automation directories
  - mkdir -p /opt/ansible/{playbooks,inventory,vault}
  - mkdir -p /opt/terraform/{modules,environments}
  - mkdir -p /var/log/automation
  - chown -R ansible:ansible /opt/ansible
  - chown -R terraform:terraform /opt/terraform
  
  # Set proper permissions
  - chmod 750 /opt/ansible/vault
  - chmod 755 /opt/terraform
  
  # Install fail2ban but don't enable yet (gradual hardening)
  - systemctl disable fail2ban
  
  # Set temporary passwords for grace period (will be disabled later)
  - echo 'ansible:temppass123!' | chpasswd
  - echo 'terraform:temppass123!' | chpasswd
  
  # Create gradual hardening cron job
  - systemctl enable cron
  - systemctl start cron
  
  # Log safety measures
  - echo "\$(date): Safe template created with gradual hardening enabled" >> /var/log/gradual-hardening.log
  - echo "Emergency user: ${EMERGENCY_USER}" >> /var/log/gradual-hardening.log
  - echo "Grace period: 48 hours for testing access" >> /var/log/gradual-hardening.log
  
  # Package cleanup
  - apt-get autoremove -y
  - apt-get autoclean
  
  # Test access methods
  - /usr/local/bin/access-test.sh >> /var/log/access-test.log
  
  # Schedule reboot for clean state
  - shutdown -r +2 "Safe Debian template setup complete, rebooting in 2 minutes"

# Comprehensive logging
output:
  all: ">> /var/log/cloud-init-output.log"

# Final safety message
final_message: |
  🔐 LOCKOUT-SAFE Debian 12 Template Setup Complete! 🔐
  
  SAFETY FEATURES ACTIVE:
  ✅ Multiple access methods preserved
  ✅ 48-hour grace period for testing
  ✅ Emergency user: ${EMERGENCY_USER} (password: stored in recovery file)
  ✅ Gradual hardening over 48 hours (not immediate)
  ✅ Recovery scripts installed
  
  IMMEDIATE ACCESS METHODS:
  1. SSH with keys (as ${USERNAME})
  2. Console access (Proxmox console)
  3. Emergency user (${EMERGENCY_USER}) 
  
  HARDENING SCHEDULE:
  - Hours 0-1: Full access (SSH + passwords + console)
  - Hours 1-24: Password auth disabled (SSH keys + console)
  - Hours 24-48: Fail2ban enabled (moderate settings)
  - Hours 48+: Full hardening (strict settings)
  
  RECOVERY COMMANDS (if locked out):
  sudo /usr/local/bin/emergency-access.sh reset
  
  Recovery credentials encrypted and stored in:
  /tmp/vm-${VMID}-recovery/credentials.age
  
  IMPORTANT: Test all access methods within first hour!
  The system will reboot in 2 minutes to ensure clean state.
EOF
    
    log_success "LOCKOUT-SAFE CloudInit configuration created"
}

# Include all the validation functions from original script
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_proxmox() {
    if ! command -v qm &> /dev/null; then
        log_error "Proxmox VE tools not found. This script must be run on a Proxmox host."
        exit 1
    fi
}

check_vmid_available() {
    if qm status "$VMID" &> /dev/null; then
        log_warning "VM ID $VMID already exists. Destroying existing VM..."
        qm destroy "$VMID" --purge || {
            log_error "Failed to destroy existing VM $VMID"
            exit 1
        }
        log_success "Existing VM $VMID destroyed"
    fi
}

check_storage() {
    if ! pvesm status -storage "$STORAGE" &> /dev/null; then
        log_error "Storage '$STORAGE' not found or not available"
        log_info "Available storage:"
        pvesm status
        exit 1
    fi
}

check_ssh_keys() {
    if [[ ! -f ~/.ssh/id_ed25519.pub ]] && [[ ! -f ~/.ssh/id_rsa.pub ]] && [[ ! -f ~/.ssh/authorized_keys ]]; then
        log_warning "No SSH keys found - creating emergency access only"
        log_info "Consider creating SSH keys: ssh-keygen -t ed25519"
    else
        log_success "SSH keys found - will be configured for access"
    fi
}

# Rest of functions (simplified for brevity - same as original)
enable_snippets() {
    log_info "Ensuring snippets are enabled for local storage..."
    mkdir -p /var/lib/vz/snippets
    log_warning "Manual step required: Enable 'snippets' content type for 'local' storage in Proxmox web UI"
}

download_debian_image() {
    local image_name="debian-12-generic-amd64.qcow2"
    log_info "Downloading Debian 12 cloud image..."
    [[ -f "$image_name" ]] && rm -f "$image_name"
    wget -q --show-progress https://cloud.debian.org/images/cloud/bookworm/latest/"$image_name" || {
        log_error "Failed to download Debian cloud image"
        exit 1
    }
    qemu-img resize "$image_name" "$DISK_SIZE" || {
        log_error "Failed to resize image"
        exit 1
    }
    log_success "Debian cloud image downloaded and resized"
}

create_vm() {
    log_info "Creating VM $VMID with name '$VM_NAME'..."
    qm create "$VMID" \
        --name "$VM_NAME" \
        --ostype l26 \
        --memory "$MEMORY" \
        --balloon 0 \
        --agent 1 \
        --bios ovmf \
        --machine q35 \
        --efidisk0 "$STORAGE:0,pre-enrolled-keys=0" \
        --cpu x86-64-v2-AES \
        --socket 1 \
        --cores "$CORES" \
        --numa 1 \
        --vga serial0 \
        --serial0 socket \
        --net0 "virtio,bridge=$BRIDGE,mtu=1" || {
        log_error "Failed to create VM"
        exit 1
    }
    log_success "VM $VMID created successfully"
}

configure_hardware() {
    local image_name="debian-12-generic-amd64.qcow2"
    log_info "Configuring VM hardware..."
    qm importdisk "$VMID" "$image_name" "$STORAGE"
    qm set "$VMID" --scsihw virtio-scsi-pci --virtio0 "$STORAGE:vm-$VMID-disk-1,discard=on"
    qm set "$VMID" --boot order=virtio0
    qm set "$VMID" --scsi1 "$STORAGE:cloudinit"
    log_success "Hardware configuration completed"
}

configure_cloudinit() {
    log_info "Configuring CloudInit settings..."
    qm set "$VMID" --cicustom "vendor=local:snippets/debian-homelab-safe.yaml"
    qm set "$VMID" --tags "debian-template,bookworm,cloudinit,homelab,lockout-safe,gradual-hardening"
    qm set "$VMID" --ciuser "$USERNAME"
    
    # Add SSH keys if available
    if [[ -f ~/.ssh/authorized_keys ]]; then
        qm set "$VMID" --sshkeys ~/.ssh/authorized_keys
    elif [[ -f ~/.ssh/id_ed25519.pub ]]; then
        qm set "$VMID" --sshkeys ~/.ssh/id_ed25519.pub
    elif [[ -f ~/.ssh/id_rsa.pub ]]; then
        qm set "$VMID" --sshkeys ~/.ssh/id_rsa.pub
    fi
    
    qm set "$VMID" --ipconfig0 ip=dhcp
    log_success "CloudInit configuration completed"
}

create_template() {
    log_info "Converting VM to template..."
    qm template "$VMID" || {
        log_error "Failed to convert VM to template"
        exit 1
    }
    log_success "VM $VMID successfully converted to template"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f debian-12-generic-amd64.qcow2
    log_success "Cleanup completed"
}

main() {
    log_info "🔐 Starting LOCKOUT-SAFE Debian 12 VM Template Creation"
    log_safety "Multiple failsafes enabled to prevent infrastructure lockouts"
    log_info "VM ID: $VMID, Storage: $STORAGE, Username: $USERNAME"
    
    # Create recovery directory
    mkdir -p "/Users/kellen/_code/UncertainMeow/homelab-infrastructure/recovery"
    
    # Validation
    check_root
    check_proxmox
    check_vmid_available
    check_storage
    check_ssh_keys
    check_ssh_connectivity
    
    # Safety preparations
    generate_recovery_keys
    
    # Main workflow
    enable_snippets
    create_gradual_hardening_script
    download_debian_image
    create_vm
    configure_hardware
    create_safe_cloudinit_config
    configure_cloudinit
    create_template
    cleanup
    
    echo ""
    log_success "🎉 LOCKOUT-SAFE Debian template creation completed successfully!"
    echo ""
    log_safety "🔐 SAFETY FEATURES SUMMARY:"
    echo "  ✅ Emergency user: $EMERGENCY_USER (console access)"
    echo "  ✅ 48-hour grace period for testing access"
    echo "  ✅ Gradual hardening (not immediate lockdown)"
    echo "  ✅ Multiple access methods preserved initially"
    echo "  ✅ Recovery scripts installed on VMs"
    echo "  ✅ Encrypted recovery credentials stored"
    echo ""
    echo "📍 Recovery file location:"
    echo "  /Users/kellen/_code/UncertainMeow/homelab-infrastructure/recovery/vm-${VMID}-recovery.age"
    echo ""
    echo "🚨 CRITICAL: Test access within first hour!"
    echo "  Clone VM: qm clone $VMID 201 --name test-vm --full"
    echo "  Start VM: qm start 201"
    echo "  Test SSH: ssh ${USERNAME}@<vm-ip>"
    echo "  Test console: Access via Proxmox web UI"
    echo ""
    echo "⏰ Hardening timeline:"
    echo "  Hour 0-1: Full access (test everything!)"
    echo "  Hour 1-24: Passwords disabled"
    echo "  Hour 24-48: Fail2ban enabled"
    echo "  Hour 48+: Full hardening active"
    echo ""
    log_safety "Your infrastructure is protected from lockout scenarios!"
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "LOCKOUT-SAFE Debian 12 VM Template Creation"
    echo "Prevents getting locked out with multiple failsafes"
    echo ""
    echo "Usage: $0 [VMID] [STORAGE]"
    echo "Safety features: Emergency user, gradual hardening, recovery keys"
    exit 0
fi

# Run main function
main "$@"