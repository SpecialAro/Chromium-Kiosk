#!/bin/bash
###################################################################################
# HA Chromium Kiosk QEMU Test Script for macOS
# This script sets up a QEMU VM to test the HA-Chromium-Kiosk setup script
###################################################################################

set -e

# Configuration variables
VM_NAME="ha-kiosk-test"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
ISO_FILE="debian-12.5.0-amd64-netinst.iso"
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
        print_message "$YELLOW" "On macOS, you can install it with: brew install qemu"
        exit 1
    fi
    print_message "$GREEN" "QEMU is installed."
}

# Function to download Debian ISO if not already downloaded
download_iso() {
    if [ ! -f "$ISO_FILE" ]; then
        print_message "$YELLOW" "Downloading Debian ISO..."
        curl -L -o "$ISO_FILE" "$ISO_URL"
        print_message "$GREEN" "Download complete."
    else
        print_message "$GREEN" "Debian ISO already downloaded."
    fi
}

# Function to create a disk image
create_disk() {
    if [ ! -f "$DISK_IMG" ]; then
        print_message "$YELLOW" "Creating disk image..."
        qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        print_message "$GREEN" "Disk image created."
    else
        print_message "$YELLOW" "Disk image already exists. Do you want to recreate it? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_message "$YELLOW" "Recreating disk image..."
            rm -f "$DISK_IMG"
            qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
            print_message "$GREEN" "Disk image recreated."
        else
            print_message "$GREEN" "Using existing disk image."
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

# Function to start the VM for installation
start_vm_install() {
    print_message "$YELLOW" "Starting VM for installation..."
    print_message "$YELLOW" "This will open a new window with the Debian installer."
    print_message "$YELLOW" "Follow the installation process and then create a snapshot."
    
    qemu-system-x86_64 \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -drive file="$DISK_IMG",format=qcow2 \
        -cdrom "$ISO_FILE" \
        -boot d \
        -accel tcg,thread=multi \
        -device virtio-net,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -name "$VM_NAME" \
        -display default
}

# Function to start the VM from disk
start_vm() {
    print_message "$YELLOW" "Starting VM from disk..."
    print_message "$YELLOW" "SSH will be forwarded to port 2222 on your host."
    print_message "$YELLOW" "You can connect with: ssh -p 2222 user@localhost"
    
    qemu-system-x86_64 \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -drive file="$DISK_IMG",format=qcow2 \
        -accel tcg,thread=multi \
        -device virtio-net,netdev=net0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -name "$VM_NAME" \
        -display default
}

# Function to prepare the test environment
prepare_test_environment() {
    print_message "$YELLOW" "Once the VM is installed and running, you need to:"
    print_message "$YELLOW" "1. Log in to the VM"
    print_message "$YELLOW" "2. Install git: sudo apt-get update && sudo apt-get install -y git"
    print_message "$YELLOW" "3. Clone your repository: git clone https://github.com/kunaalm/HA-Chromium-Kiosk.git"
    print_message "$YELLOW" "4. Run the script: cd HA-Chromium-Kiosk && sudo ./ha-chromium-kiosk-setup.sh install"
    print_message "$YELLOW" "5. After testing, create a snapshot with: ./tests/qemu-test-kiosk-mac.sh snapshot"
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Test the HA-Chromium-Kiosk setup script in a QEMU VM on macOS."
    echo ""
    echo "Options:"
    echo "  setup       Download ISO and create disk image"
    echo "  install     Start VM with installation media"
    echo "  start       Start VM from disk"
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
        download_iso
        create_disk
        ;;
    install)
        check_qemu
        start_vm_install
        prepare_test_environment
        ;;
    start)
        check_qemu
        start_vm
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
