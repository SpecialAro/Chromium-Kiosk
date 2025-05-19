#!/bin/bash
###################################################################################
# HA Chromium Kiosk QEMU Test Script (Unified for Linux and macOS)
# This script sets up a QEMU VM to test the HA-Chromium-Kiosk setup script
###################################################################################

set -e

# Detect operating system
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    *)          echo "Unsupported operating system: ${OS}"; exit 1;;
esac

# Configuration variables
VM_NAME="ha-kiosk-test"
DEBIAN_CLOUD_URL="http://cloud.debian.org/images/cloud/bookworm/latest"
VM_IMAGE_URL="$DEBIAN_CLOUD_URL/debian-12-nocloud-amd64.qcow2"
VM_IMAGE_FILE="debian-nocloud-amd64.qcow2"
DISK_IMG="${VM_NAME}.qcow2"
DISK_SIZE="20G"
MEMORY="2G"
CPUS="2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if QEMU is installed
check_qemu() {
    if ! command -v qemu-img &> /dev/null || ! command -v qemu-system-x86_64 &> /dev/null; then
        print_message "$RED" "QEMU is not installed. Please install QEMU first."
        if [ "$PLATFORM" = "macos" ]; then
            print_message "$YELLOW" "On macOS, you can install it with: brew install qemu"
        else
            print_message "$YELLOW" "On Linux, you can install it with: sudo apt-get install qemu-system-x86"
        fi
        exit 1
    fi
    print_message "$GREEN" "QEMU is installed."
}

# Function to download Debian VM image if not already downloaded
download_vm_image() {
    if [ ! -f "$VM_IMAGE_FILE" ]; then
        print_message "$YELLOW" "Downloading Debian VM image..."
        curl -L -o "$VM_IMAGE_FILE" "$VM_IMAGE_URL"
        print_message "$GREEN" "Download complete."
    else
        print_message "$GREEN" "Debian VM image already downloaded."
    fi
}

# Function to prepare the VM disk image
prepare_disk() {
    if [ ! -f "$DISK_IMG" ]; then
        print_message "$YELLOW" "Preparing VM disk image..."
        cp "$VM_IMAGE_FILE" "$DISK_IMG"
        # Resize the disk if needed
        qemu-img resize "$DISK_IMG" "$DISK_SIZE"
        print_message "$GREEN" "VM disk image prepared."
    else
        print_message "$YELLOW" "VM disk image already exists. Do you want to recreate it? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_message "$YELLOW" "Recreating VM disk image..."
            rm -f "$DISK_IMG"
            cp "$VM_IMAGE_FILE" "$DISK_IMG"
            # Resize the disk if needed
            qemu-img resize "$DISK_IMG" "$DISK_SIZE"
            print_message "$GREEN" "VM disk image recreated."
        else
            print_message "$GREEN" "Using existing VM disk image."
        fi
    fi
}

# Function to create a snapshot
create_snapshot() {
    print_message "$YELLOW" "Creating snapshot..."
    qemu-img snapshot -c "clean_install" "$DISK_IMG"
    print_message "$GREEN" "Snapshot 'clean_install' created."
}

# Function to revert to a snapshot
revert_to_snapshot() {
    print_message "$YELLOW" "Reverting to snapshot 'clean_install'..."
    qemu-img snapshot -a "clean_install" "$DISK_IMG"
    print_message "$GREEN" "Reverted to snapshot 'clean_install'."
}

# Function to list snapshots
list_snapshots() {
    print_message "$YELLOW" "Available snapshots:"
    qemu-img snapshot -l "$DISK_IMG"
}

# Function to start the VM for the first time
start_vm_first_time() {
    print_message "$YELLOW" "Starting VM for the first time..."
    print_message "$YELLOW" "This will open a new window with the Debian VM."
    print_message "$YELLOW" "The default login for the nocloud image is 'root' with no password (passwordless login)."
    print_message "$YELLOW" "After setting up the VM, create a snapshot."

    # Platform-specific VM launch options
    if [ "$PLATFORM" = "macos" ]; then
        # macOS uses software emulation (TCG) instead of KVM
        qemu-system-x86_64 \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$DISK_IMG",format=qcow2 \
            -accel tcg,thread=multi \
            -device virtio-net,netdev=net0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -name "$VM_NAME" \
            -display default \
            -monitor stdio
    else
        # Linux uses KVM for hardware acceleration
        qemu-system-x86_64 \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$DISK_IMG",format=qcow2 \
            -enable-kvm \
            -device virtio-net,netdev=net0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -name "$VM_NAME" \
            -display default \
            -monitor stdio
    fi
}

# Function to start the VM from disk
start_vm() {
    print_message "$YELLOW" "Starting VM from disk..."
    print_message "$YELLOW" "SSH will be forwarded to port 2222 on your host."
    print_message "$YELLOW" "You can connect with: ssh -p 2222 root@localhost"
    print_message "$YELLOW" "Note: SSH server may not be installed by default. See setup instructions below."

    # Platform-specific VM launch options
    if [ "$PLATFORM" = "macos" ]; then
        # macOS uses software emulation (TCG) instead of KVM
        qemu-system-x86_64 \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$DISK_IMG",format=qcow2 \
            -accel tcg,thread=multi \
            -device virtio-net,netdev=net0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -name "$VM_NAME" \
            -display default \
            -monitor stdio
    else
        # Linux uses KVM for hardware acceleration
        qemu-system-x86_64 \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$DISK_IMG",format=qcow2 \
            -enable-kvm \
            -device virtio-net,netdev=net0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -name "$VM_NAME" \
            -display default \
            -monitor stdio
    fi
}

# Function to prepare the test environment
prepare_test_environment() {
    print_message "$YELLOW" "Once the VM is installed and running, you need to:"
    print_message "$YELLOW" "1. Log in to the VM through the QEMU console window (username: root, no password)"
    print_message "$YELLOW" "2. Set up SSH access (optional, but recommended for easier testing):"
    print_message "$YELLOW" "   a. Install SSH server: apt-get update && apt-get install -y openssh-server"
    print_message "$YELLOW" "   b. Set a root password: passwd root"
    print_message "$YELLOW" "   c. Configure SSH to allow root login with password:"
    print_message "$YELLOW" "      sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"
    print_message "$YELLOW" "   d. Restart SSH service: systemctl restart ssh"
    print_message "$YELLOW" "   e. Now you can connect from your host: ssh -p 2222 root@localhost"
    print_message "$YELLOW" "3. Install git and bash: apt-get update && apt-get install -y git bash"
    print_message "$YELLOW" "4. Clone your repository: git clone https://github.com/kunaalm/HA-Chromium-Kiosk.git"
    print_message "$YELLOW" "5. Make the script executable: cd HA-Chromium-Kiosk && chmod +x ha-chromium-kiosk-setup.sh"
    print_message "$YELLOW" "6. Run the script with bash: bash ./ha-chromium-kiosk-setup.sh install"
    print_message "$YELLOW" "7. After testing, create a snapshot with: ./tests/qemu-test-kiosk.sh snapshot"
}

# Function to create a setup script for SSH
create_ssh_setup_script() {
    print_message "$YELLOW" "Creating SSH setup script..."
    cat > ssh-setup.sh <<EOF
#!/bin/bash
# Script to set up SSH access in the Debian VM

# Update package lists
apt-get update

# Install SSH server and bash
apt-get install -y openssh-server bash

# Set root password to 'kiosk' (for testing only)
echo "root:kiosk" | chpasswd

# Configure SSH to allow root login with password
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart SSH service
systemctl restart ssh

echo "SSH setup complete. You can now connect with: ssh -p 2222 root@localhost"
echo "The root password is: kiosk"
EOF
    chmod +x ssh-setup.sh
    print_message "$GREEN" "SSH setup script created: ssh-setup.sh"
    print_message "$YELLOW" "Copy this script to the VM and run it to set up SSH access."
    print_message "$YELLOW" "You can use the QEMU console to do this."
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Test the HA-Chromium-Kiosk setup script in a QEMU VM."
    echo ""
    echo "Options:"
    echo "  setup       Download VM image and prepare disk"
    echo "  first-boot  Start VM for the first time"
    echo "  start       Start VM from disk"
    echo "  ssh-setup   Create a script to set up SSH access in the VM"
    echo "  snapshot    Create a snapshot of the current VM state"
    echo "  revert      Revert to the clean snapshot"
    echo "  list        List available snapshots"
    echo "  help        Display this help message"
    echo ""
}

# Main script
case "$1" in
    setup)
        check_qemu
        download_vm_image
        prepare_disk
        ;;
    first-boot)
        check_qemu
        start_vm_first_time
        prepare_test_environment
        ;;
    start)
        check_qemu
        start_vm
        ;;
    ssh-setup)
        create_ssh_setup_script
        ;;
    snapshot)
        check_qemu
        create_snapshot
        ;;
    revert)
        check_qemu
        revert_to_snapshot
        ;;
    list)
        check_qemu
        list_snapshots
        ;;
    help|*)
        show_help
        ;;
esac
