#!/bin/bash
###################################################################################
# HA Chromium Kiosk Test Script
# This script sets up a VirtualBox VM to test the HA-Chromium-Kiosk setup script
###################################################################################

set -e

# Configuration variables
VM_NAME="HA-Kiosk-Test"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
ISO_FILE="debian-12.5.0-amd64-netinst.iso"
VM_MEMORY=2048
VM_DISK_SIZE=20000
VM_CPUS=2

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

# Function to check if VirtualBox is installed
check_virtualbox() {
    if ! command -v VBoxManage &> /dev/null; then
        print_message "$RED" "VirtualBox is not installed. Please install VirtualBox first."
        exit 1
    fi
    print_message "$GREEN" "VirtualBox is installed."
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

# Function to create a new VM
create_vm() {
    # Check if VM already exists
    if VBoxManage list vms | grep -q "\"$VM_NAME\""; then
        print_message "$YELLOW" "VM '$VM_NAME' already exists. Do you want to remove it and create a new one? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_message "$YELLOW" "Removing existing VM..."
            VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
            sleep 2
            VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        else
            print_message "$YELLOW" "Using existing VM."
            return
        fi
    fi

    print_message "$YELLOW" "Creating new VM '$VM_NAME'..."
    
    # Create VM
    VBoxManage createvm --name "$VM_NAME" --ostype "Debian_64" --register
    
    # Set memory and network
    VBoxManage modifyvm "$VM_NAME" --memory "$VM_MEMORY" --cpus "$VM_CPUS" --acpi on --boot1 dvd
    VBoxManage modifyvm "$VM_NAME" --nic1 nat
    
    # Create and attach storage
    VBoxManage createhd --filename "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi" --size "$VM_DISK_SIZE"
    VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAHCI
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
    
    # Attach DVD drive with Debian ISO
    VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
    VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$(pwd)/$ISO_FILE"
    
    print_message "$GREEN" "VM created successfully."
}

# Function to start the VM
start_vm() {
    print_message "$YELLOW" "Starting VM '$VM_NAME'..."
    VBoxManage startvm "$VM_NAME"
    print_message "$GREEN" "VM started. Please complete the Debian installation."
    print_message "$YELLOW" "Recommended installation options:"
    print_message "$YELLOW" "- Install a minimal system without desktop environment"
    print_message "$YELLOW" "- When asked for software selection, only select 'SSH server' and 'standard system utilities'"
    print_message "$YELLOW" "- Create a user with username 'test' and password 'test'"
}

# Function to prepare the test environment
prepare_test_environment() {
    print_message "$YELLOW" "Once the VM is installed and running, you need to:"
    print_message "$YELLOW" "1. Log in to the VM"
    print_message "$YELLOW" "2. Install git: sudo apt-get update && sudo apt-get install -y git"
    print_message "$YELLOW" "3. Clone your repository: git clone https://github.com/kunaalm/HA-Chromium-Kiosk.git"
    print_message "$YELLOW" "4. Run the script: cd HA-Chromium-Kiosk && sudo ./ha-chromium-kiosk-setup.sh install"
}

# Function to create a snapshot of the VM
create_snapshot() {
    print_message "$YELLOW" "Creating snapshot of the VM..."
    VBoxManage snapshot "$VM_NAME" take "clean_install" --description "Clean Debian installation"
    print_message "$GREEN" "Snapshot created. You can now test the script and revert to this snapshot if needed."
}

# Function to revert to a snapshot
revert_to_snapshot() {
    print_message "$YELLOW" "Reverting to clean snapshot..."
    VBoxManage snapshot "$VM_NAME" restore "clean_install"
    print_message "$GREEN" "VM reverted to clean state."
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Test the HA-Chromium-Kiosk setup script in a VirtualBox VM."
    echo ""
    echo "Options:"
    echo "  setup       Create and start a new VM with Debian"
    echo "  snapshot    Create a snapshot of the current VM state"
    echo "  revert      Revert to the clean snapshot"
    echo "  start       Start the VM"
    echo "  help        Display this help message"
    echo ""
}

# Main script
case "$1" in
    setup)
        check_virtualbox
        download_iso
        create_vm
        start_vm
        prepare_test_environment
        ;;
    snapshot)
        create_snapshot
        ;;
    revert)
        revert_to_snapshot
        ;;
    start)
        VBoxManage startvm "$VM_NAME"
        ;;
    help|*)
        show_help
        ;;
esac
