#!/bin/bash

# Debian 12 (Bookworm) CloudInit VM Template Creation Script
# Based on UntouchedWagons/Ubuntu-CloudInit-Docs Debian sample
# Customized for Kellen's Homelab Infrastructure - Senior DevOps Grade

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration Variables
VMID=${1:-9001}           # Default VM ID, can be overridden
STORAGE=${2:-local-lvm}   # Default storage, can be overridden  
VM_NAME="debian-12-homelab-template"
DISK_SIZE="32G"           # Larger disk for development work
MEMORY="2048"             # More memory for containers
CORES="2"                 # Multiple cores for better performance
BRIDGE="vmbr0"            # Network bridge
USERNAME=${USER}          # Use current user as default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Validation functions
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
    if [[ ! -f ~/.ssh/authorized_keys ]]; then
        log_error "SSH authorized_keys file not found at ~/.ssh/authorized_keys"
        log_info "Please create SSH keys first: ssh-keygen -t ed25519"
        exit 1
    fi
}

# Main functions
enable_snippets() {
    log_info "Ensuring snippets are enabled for local storage..."
    
    # Check if snippets directory exists
    if [[ ! -d /var/lib/vz/snippets ]]; then
        log_info "Creating snippets directory..."
        mkdir -p /var/lib/vz/snippets
    fi
    
    # Note: Manual step required for snippets content type in web UI
    log_warning "Manual step required: Enable 'snippets' content type for 'local' storage in Proxmox web UI"
    log_info "Go to: Datacenter > Storage > local > Edit > Content > Add 'snippets'"
}

download_debian_image() {
    local image_name="debian-12-generic-amd64.qcow2"
    
    log_info "Downloading Debian 12 (Bookworm) cloud image..."
    
    # Remove existing image if present
    if [[ -f "$image_name" ]]; then
        log_info "Removing existing image..."
        rm -f "$image_name"
    fi
    
    # Download the cloud image
    wget -q --show-progress https://cloud.debian.org/images/cloud/bookworm/latest/"$image_name" || {
        log_error "Failed to download Debian cloud image"
        exit 1
    }
    
    log_info "Resizing image to $DISK_SIZE..."
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
    
    # Import the disk image
    log_info "Importing disk image..."
    qm importdisk "$VMID" "$image_name" "$STORAGE" || {
        log_error "Failed to import disk"
        exit 1
    }
    
    # Attach the disk
    log_info "Attaching disk to VM..."
    qm set "$VMID" \
        --scsihw virtio-scsi-pci \
        --virtio0 "$STORAGE:vm-$VMID-disk-1,discard=on" || {
        log_error "Failed to attach disk"
        exit 1
    }
    
    # Set boot order
    log_info "Setting boot order..."
    qm set "$VMID" --boot order=virtio0 || {
        log_error "Failed to set boot order"
        exit 1
    }
    
    # Add CloudInit drive
    log_info "Adding CloudInit drive..."
    qm set "$VMID" --scsi1 "$STORAGE:cloudinit" || {
        log_error "Failed to add CloudInit drive"
        exit 1
    }
    
    log_success "Hardware configuration completed"
}

create_cloudinit_config() {
    log_info "Creating CloudInit vendor configuration..."
    
    cat << 'EOF' > /var/lib/vz/snippets/debian-homelab.yaml
#cloud-config
# Debian 12 Homelab Template CloudInit Configuration
# Security-hardened and optimized for infrastructure automation

# Package management
package_update: true
package_upgrade: true
package_reboot_if_required: false

# Essential packages for homelab infrastructure
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

# Create automation users for Ansible and Terraform
users:
  - default  # Keep the default user from CloudInit
  - name: ansible
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys: []  # Will be populated during deployment
    lock_passwd: true
  - name: terraform
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys: []  # Will be populated during deployment
    lock_passwd: true

# System configuration
timezone: 'America/New_York'
locale: 'en_US.UTF-8'

# SSH hardening configuration
ssh_pwauth: false
ssh_deletekeys: true
ssh_genkeytypes: ['ed25519', 'rsa']
ssh_keys:
  ed25519_private: |
    # This will be generated automatically
  ed25519_public: |
    # This will be generated automatically

# Sysctl optimizations for containers and automation
write_files:
  - path: /etc/sysctl.d/99-homelab.conf
    content: |
      # Container optimizations
      vm.max_map_count=262144
      fs.file-max=1000000
      net.core.somaxconn=32768
      net.ipv4.ip_local_port_range=1024 65535
      
      # Security hardening
      net.ipv4.conf.all.send_redirects=0
      net.ipv4.conf.default.send_redirects=0
      net.ipv4.conf.all.accept_redirects=0
      net.ipv4.conf.default.accept_redirects=0
      net.ipv4.conf.all.secure_redirects=0
      net.ipv4.conf.default.secure_redirects=0
      net.ipv6.conf.all.accept_redirects=0
      net.ipv6.conf.default.accept_redirects=0
      
  - path: /etc/ssh/sshd_config.d/99-homelab-security.conf
    content: |
      # SSH Security Hardening
      PermitRootLogin no
      PasswordAuthentication no
      ChallengeResponseAuthentication no
      UsePAM yes
      X11Forwarding no
      PrintMotd no
      TCPKeepAlive no
      Compression no
      ClientAliveInterval 300
      ClientAliveCountMax 2
      MaxAuthTries 3
      MaxSessions 2
      Protocol 2
      
      # Allow only specific users (adjust as needed)
      AllowUsers ansible terraform
      
  - path: /etc/fail2ban/jail.d/ssh-homelab.conf
    content: |
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
      bantime = 3600
      findtime = 600

# Security and system hardening commands
runcmd:
  # System service management
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now ufw
  - systemctl enable --now fail2ban
  
  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-homelab.conf
  
  # UFW firewall configuration - restrictive by default
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw allow from 192.168.0.0/16 to any port 22 comment 'SSH from local networks'
  - ufw allow from 10.0.0.0/8 to any port 22 comment 'SSH from private networks'
  - ufw --force enable
  
  # Create directory structure for automation tools
  - mkdir -p /opt/ansible/{playbooks,inventory,vault}
  - mkdir -p /opt/terraform/{modules,environments}
  - mkdir -p /var/log/automation
  - chown -R ansible:ansible /opt/ansible
  - chown -R terraform:terraform /opt/terraform
  
  # Set proper permissions for automation directories
  - chmod 750 /opt/ansible/vault
  - chmod 755 /opt/terraform
  
  # Restart SSH to apply hardened configuration
  - systemctl restart ssh
  
  # Package cleanup
  - apt-get autoremove -y
  - apt-get autoclean
  
  # Final reboot to ensure all changes are active
  - shutdown -r +1 "Debian homelab template setup complete, rebooting in 1 minute"

# Logging configuration
output:
  all: ">> /var/log/cloud-init-output.log"

# Final message
final_message: |
  Debian 12 Homelab Template Setup Complete!
  
  Security Features Enabled:
  - SSH key authentication only
  - UFW firewall configured
  - Fail2ban monitoring SSH
  - Security-hardened kernel parameters
  
  Automation Users Created:
  - ansible (for Ansible automation)
  - terraform (for Terraform deployments)
  
  System is ready for infrastructure automation!
  
  The system will reboot in 1 minute to ensure all changes are active.
EOF
    
    log_success "CloudInit configuration created with security hardening"
}

configure_cloudinit() {
    log_info "Configuring CloudInit settings..."
    
    # Set custom vendor configuration
    qm set "$VMID" --cicustom "vendor=local:snippets/debian-homelab.yaml" || {
        log_error "Failed to set CloudInit vendor config"
        exit 1
    }
    
    # Add descriptive tags
    qm set "$VMID" --tags "debian-template,bookworm,cloudinit,homelab,security-hardened,automation-ready" || {
        log_error "Failed to set tags"
        exit 1
    }
    
    # Set user and SSH keys
    qm set "$VMID" --ciuser "$USERNAME" || {
        log_error "Failed to set CloudInit user"
        exit 1
    }
    
    qm set "$VMID" --sshkeys ~/.ssh/authorized_keys || {
        log_error "Failed to set SSH keys"
        exit 1
    }
    
    # Set network to DHCP
    qm set "$VMID" --ipconfig0 ip=dhcp || {
        log_error "Failed to set network configuration"
        exit 1
    }
    
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

print_usage() {
    echo "Usage: $0 [VMID] [STORAGE]"
    echo ""
    echo "Creates a security-hardened Debian 12 VM template optimized for homelab infrastructure"
    echo ""
    echo "Parameters:"
    echo "  VMID      VM ID for the template (default: 9001)"
    echo "  STORAGE   Proxmox storage name (default: local-lvm)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use defaults (VM 9001, local-lvm)"
    echo "  $0 9002              # Use VM 9002, local-lvm"
    echo "  $0 9002 local-zfs    # Use VM 9002, local-zfs storage"
    echo ""
    echo "Requirements:"
    echo "  - Must be run as root on Proxmox host"
    echo "  - SSH keys must exist at ~/.ssh/authorized_keys"
    echo "  - 'snippets' content type enabled for local storage"
}

main() {
    log_info "Starting Debian 12 Security-Hardened VM Template Creation"
    log_info "VM ID: $VMID, Storage: $STORAGE, Username: $USERNAME"
    
    # Validation
    check_root
    check_proxmox
    check_vmid_available
    check_storage
    check_ssh_keys
    
    # Main workflow
    enable_snippets
    download_debian_image
    create_vm
    configure_hardware
    create_cloudinit_config
    configure_cloudinit
    create_template
    cleanup
    
    echo ""
    log_success "🎉 Debian homelab template creation completed successfully!"
    echo ""
    echo "Template Details:"
    echo "  VM ID: $VMID"
    echo "  Name: $VM_NAME"
    echo "  Storage: $STORAGE"
    echo "  Disk Size: $DISK_SIZE"
    echo "  Memory: ${MEMORY}MB"
    echo "  CPU Cores: $CORES"
    echo "  Username: $USERNAME"
    echo ""
    echo "Security Features:"
    echo "  ✓ SSH key authentication only"
    echo "  ✓ UFW firewall enabled"
    echo "  ✓ Fail2ban monitoring"
    echo "  ✓ Security-hardened SSH config"
    echo "  ✓ Kernel security parameters"
    echo ""
    echo "Automation Features:"
    echo "  ✓ Ansible user with sudo access"
    echo "  ✓ Terraform user with sudo access"
    echo "  ✓ Pre-configured directory structure"
    echo "  ✓ Container-optimized settings"
    echo ""
    echo "Next Steps:"
    echo "1. Clone this template to create new VMs"
    echo "2. Add SSH keys for ansible/terraform users"
    echo "3. Adjust memory and CPU cores as needed"
    echo "4. Deploy services via Ansible automation"
    echo ""
    echo "Clone Example:"
    echo "  qm clone $VMID 201 --name gitlab-vm --full"
    echo "  qm set 201 --memory 4096 --cores 4"
    echo "  qm start 201"
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    print_usage
    exit 0
fi

# Run main function
main "$@"