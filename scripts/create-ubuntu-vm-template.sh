#!/bin/bash

# Ubuntu 24.04 LTS CloudInit VM Template Creation Script
# Based on UntouchedWagons/Ubuntu-CloudInit-Docs
# Customized for Kellen's Homelab Infrastructure

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration Variables
VMID=${1:-9000}           # Default VM ID, can be overridden
STORAGE=${2:-local-lvm}   # Default storage, can be overridden  
VM_NAME="ubuntu-2404-homelab-template"
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

download_ubuntu_image() {
    local image_name="noble-server-cloudimg-amd64.img"
    
    log_info "Downloading Ubuntu 24.04 LTS cloud image..."
    
    # Remove existing image if present
    if [[ -f "$image_name" ]]; then
        log_info "Removing existing image..."
        rm -f "$image_name"
    fi
    
    # Download the cloud image
    wget -q --show-progress https://cloud-images.ubuntu.com/noble/current/"$image_name" || {
        log_error "Failed to download Ubuntu cloud image"
        exit 1
    }
    
    log_info "Resizing image to $DISK_SIZE..."
    qemu-img resize "$image_name" "$DISK_SIZE" || {
        log_error "Failed to resize image"
        exit 1
    }
    
    log_success "Ubuntu cloud image downloaded and resized"
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
        --cpu host \
        --socket 1 \
        --cores "$CORES" \
        --vga serial0 \
        --serial0 socket \
        --net0 "virtio,bridge=$BRIDGE" || {
        log_error "Failed to create VM"
        exit 1
    }
    
    log_success "VM $VMID created successfully"
}

configure_hardware() {
    local image_name="noble-server-cloudimg-amd64.img"
    
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
    
    cat << 'EOF' > /var/lib/vz/snippets/ubuntu-homelab.yaml
#cloud-config
# Ubuntu Homelab Template CloudInit Configuration
# Optimized for development and container workloads

# Package management
package_update: true
package_upgrade: true
package_reboot_if_required: false

# Essential packages for homelab use
packages:
  - qemu-guest-agent
  - curl
  - wget
  - git
  - htop
  - vim
  - tmux
  - tree
  - unzip
  - software-properties-common
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - ufw
  - fail2ban

# System configuration
timezone: 'America/New_York'
locale: 'en_US.UTF-8'

# SSH configuration for security
ssh_pwauth: false
ssh_deletekeys: true
ssh_genkeytypes: ['ed25519', 'rsa']

# UFW firewall basic setup
runcmd:
  # Start and enable essential services
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
  - systemctl enable --now ufw
  - systemctl enable --now fail2ban
  
  # Basic firewall configuration
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw --force enable
  
  # Optimize for containers and development
  - echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
  - echo 'fs.file-max=1000000' >> /etc/sysctl.conf
  - sysctl -p
  
  # Clean up
  - apt-get autoremove -y
  - apt-get autoclean
  
  # Reboot to ensure all changes take effect
  - shutdown -r +1 "Rebooting after initial setup in 1 minute"

# Power management - ensure graceful shutdown
power_state:
  mode: reboot
  message: "Initial CloudInit setup complete, rebooting..."
  condition: true

# Logging
output:
  all: ">> /var/log/cloud-init.log"
EOF
    
    log_success "CloudInit configuration created"
}

configure_cloudinit() {
    log_info "Configuring CloudInit settings..."
    
    # Set custom vendor configuration
    qm set "$VMID" --cicustom "vendor=local:snippets/ubuntu-homelab.yaml" || {
        log_error "Failed to set CloudInit vendor config"
        exit 1
    }
    
    # Add descriptive tags
    qm set "$VMID" --tags "ubuntu-template,24.04,cloudinit,homelab,docker-ready" || {
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
    rm -f noble-server-cloudimg-amd64.img
    log_success "Cleanup completed"
}

print_usage() {
    echo "Usage: $0 [VMID] [STORAGE]"
    echo ""
    echo "Creates a Ubuntu 24.04 LTS VM template optimized for homelab use"
    echo ""
    echo "Parameters:"
    echo "  VMID      VM ID for the template (default: 9000)"
    echo "  STORAGE   Proxmox storage name (default: local-lvm)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use defaults (VM 9000, local-lvm)"
    echo "  $0 9001              # Use VM 9001, local-lvm"
    echo "  $0 9001 local-zfs    # Use VM 9001, local-zfs storage"
    echo ""
    echo "Requirements:"
    echo "  - Must be run as root on Proxmox host"
    echo "  - SSH keys must exist at ~/.ssh/authorized_keys"
    echo "  - 'snippets' content type enabled for local storage"
}

main() {
    log_info "Starting Ubuntu 24.04 LTS VM Template Creation"
    log_info "VM ID: $VMID, Storage: $STORAGE, Username: $USERNAME"
    
    # Validation
    check_root
    check_proxmox
    check_vmid_available
    check_storage
    check_ssh_keys
    
    # Main workflow
    enable_snippets
    download_ubuntu_image
    create_vm
    configure_hardware
    create_cloudinit_config
    configure_cloudinit
    create_template
    cleanup
    
    echo ""
    log_success "🎉 Ubuntu homelab template creation completed successfully!"
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
    echo "Next Steps:"
    echo "1. Clone this template to create new VMs"
    echo "2. Adjust memory and CPU cores for cloned VMs as needed"
    echo "3. VMs will auto-configure on first boot via CloudInit"
    echo "4. SSH access available after initial reboot (~2-3 minutes)"
    echo ""
    echo "Clone Example:"
    echo "  qm clone $VMID 101 --name my-new-vm --full"
    echo "  qm set 101 --memory 4096 --cores 4"
    echo "  qm start 101"
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    print_usage
    exit 0
fi

# Run main function
main "$@"