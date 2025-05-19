#!/bin/bash
###################################################################################
# HA Chromium Kiosk Proxmox Test Script
# Author: Kunaal Mahanti (kunaal.mahanti@gmail.com)
# URL: https://github.com/kunaalm/ha-chromium-kiosk
#
# Script to deploy and test HA Chromium Kiosk on a Proxmox VM
#
# This script:
# 1. Creates a Debian VM on a Proxmox server
# 2. Installs necessary packages
# 3. Copies the HA Chromium Kiosk script to the VM
# 4. Runs the installation
# 5. Performs tests to verify functionality
#
# Prerequisites:
# - SSH access to Proxmox server with privileges to create VMs
# - Debian cloud image available on Proxmox server
# - SSH key for passwordless access to the VM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###################################################################################

set -e

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables - modify these as needed
PROXMOX_HOST=""
PROXMOX_USER="root"
PROXMOX_NODE="pve"
VM_ID=""
VM_NAME="ha-kiosk-test"
VM_MEMORY="2048"
VM_CORES="2"
VM_STORAGE="local-lvm"
VM_NETWORK="virtio,bridge=vmbr0"
DEBIAN_TEMPLATE=""
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
HA_IP=""
HA_PORT="8123"
HA_DASHBOARD_PATH="lovelace/default_view"

# Function to display usage information
usage() {
    echo -e "${BLUE}Usage:${NC} $0 [options]"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  -h, --host HOST       Proxmox host address (required)"
    echo "  -u, --user USER       Proxmox user (default: root)"
    echo "  -n, --node NODE       Proxmox node (default: pve)"
    echo "  -i, --id ID           VM ID to use (required)"
    echo "  -t, --template TMPL   Debian template to use (required)"
    echo "  -m, --memory MEM      VM memory in MB (default: 2048)"
    echo "  -c, --cores CORES     VM CPU cores (default: 2)"
    echo "  -s, --storage STORE   VM storage location (default: local-lvm)"
    echo "  -k, --key KEY         SSH public key path (default: ~/.ssh/id_rsa.pub)"
    echo "  -a, --ha-ip IP        Home Assistant IP address (required)"
    echo "  -p, --ha-port PORT    Home Assistant port (default: 8123)"
    echo "  --help                Display this help message"
    echo
    echo -e "${BLUE}Example:${NC}"
    echo "  $0 --host proxmox.example.com --id 100 --template debian-11-generic-amd64.qcow2 --ha-ip 192.168.1.100"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--host)
            PROXMOX_HOST="$2"
            shift 2
            ;;
        -u|--user)
            PROXMOX_USER="$2"
            shift 2
            ;;
        -n|--node)
            PROXMOX_NODE="$2"
            shift 2
            ;;
        -i|--id)
            VM_ID="$2"
            shift 2
            ;;
        -t|--template)
            DEBIAN_TEMPLATE="$2"
            shift 2
            ;;
        -m|--memory)
            VM_MEMORY="$2"
            shift 2
            ;;
        -c|--cores)
            VM_CORES="$2"
            shift 2
            ;;
        -s|--storage)
            VM_STORAGE="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        -a|--ha-ip)
            HA_IP="$2"
            shift 2
            ;;
        -p|--ha-port)
            HA_PORT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$PROXMOX_HOST" ] || [ -z "$VM_ID" ] || [ -z "$DEBIAN_TEMPLATE" ] || [ -z "$HA_IP" ]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}Error: SSH public key not found at $SSH_KEY_PATH${NC}"
    exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_PATH")

echo -e "${BLUE}=== HA Chromium Kiosk Proxmox Test ===${NC}"
echo -e "${YELLOW}This script will create a VM on your Proxmox server and test the HA Chromium Kiosk setup.${NC}"
echo
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Proxmox Host: ${GREEN}$PROXMOX_HOST${NC}"
echo -e "  Proxmox User: ${GREEN}$PROXMOX_USER${NC}"
echo -e "  Proxmox Node: ${GREEN}$PROXMOX_NODE${NC}"
echo -e "  VM ID:        ${GREEN}$VM_ID${NC}"
echo -e "  VM Name:      ${GREEN}$VM_NAME${NC}"
echo -e "  VM Memory:    ${GREEN}$VM_MEMORY MB${NC}"
echo -e "  VM Cores:     ${GREEN}$VM_CORES${NC}"
echo -e "  VM Storage:   ${GREEN}$VM_STORAGE${NC}"
echo -e "  Template:     ${GREEN}$DEBIAN_TEMPLATE${NC}"
echo -e "  HA IP:        ${GREEN}$HA_IP${NC}"
echo -e "  HA Port:      ${GREEN}$HA_PORT${NC}"
echo

# Confirm before proceeding
read -p "Do you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

echo -e "${BLUE}Step 1: Creating VM on Proxmox...${NC}"
ssh "$PROXMOX_USER@$PROXMOX_HOST" "
    # Check if VM already exists
    if qm status $VM_ID &>/dev/null; then
        echo 'VM with ID $VM_ID already exists. Stopping and removing it...'
        qm stop $VM_ID --timeout 60 || true
        qm destroy $VM_ID || { echo 'Failed to destroy existing VM'; exit 1; }
    fi

    # Create VM
    qm create $VM_ID --name $VM_NAME --memory $VM_MEMORY --cores $VM_CORES --net0 $VM_NETWORK

    # Import disk from template
    qm importdisk $VM_ID /var/lib/vz/template/iso/$DEBIAN_TEMPLATE $VM_STORAGE

    # Configure VM
    qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VM_ID-disk-0
    qm set $VM_ID --boot c --bootdisk scsi0
    qm set $VM_ID --serial0 socket --vga serial0

    # Set cloud-init parameters
    qm set $VM_ID --ide2 $VM_STORAGE:cloudinit
    qm set $VM_ID --ciuser debian
    qm set $VM_ID --cipassword debian
    qm set $VM_ID --sshkeys \"$SSH_KEY\"
    qm set $VM_ID --ipconfig0 ip=dhcp

    # Start VM
    qm start $VM_ID

    echo 'VM created and started successfully.'
"

echo -e "${GREEN}✓ VM created successfully${NC}"
echo -e "${BLUE}Step 2: Waiting for VM to boot and obtain IP...${NC}"

# Wait for VM to boot and get its IP
VM_IP=""
MAX_ATTEMPTS=30
ATTEMPT=0

while [ -z "$VM_IP" ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -ne "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking VM IP...\r"

    # Get VM IP from Proxmox
    VM_IP=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm guest cmd $VM_ID network-get-interfaces | grep -oP '\"ip-addresses\":\[\{\"ip-address\":\"\K[0-9.]+' | head -1" 2>/dev/null || true)

    if [ -z "$VM_IP" ]; then
        sleep 5
    fi
done

if [ -z "$VM_IP" ]; then
    echo -e "${RED}Error: Could not determine VM IP address after $MAX_ATTEMPTS attempts${NC}"
    exit 1
fi

echo -e "${GREEN}✓ VM IP address: $VM_IP${NC}"
echo -e "${BLUE}Step 3: Waiting for SSH to become available...${NC}"

# Wait for SSH to become available
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -ne "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking SSH connectivity...\r"

    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "debian@$VM_IP" "echo SSH connection successful" &>/dev/null; then
        echo -e "\n${GREEN}✓ SSH connection established${NC}"
        break
    fi

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "\n${RED}Error: Could not establish SSH connection after $MAX_ATTEMPTS attempts${NC}"
        exit 1
    fi

    sleep 5
done

echo -e "${BLUE}Step 4: Copying HA Chromium Kiosk script to VM...${NC}"

# Copy the script to the VM
scp -o StrictHostKeyChecking=no "../ha-chromium-kiosk-setup.sh" "debian@$VM_IP:~/"

echo -e "${GREEN}✓ Script copied successfully${NC}"
echo -e "${BLUE}Step 5: Installing prerequisites on VM...${NC}"

# Install prerequisites
ssh -o StrictHostKeyChecking=no "debian@$VM_IP" "
    sudo apt-get update
    sudo apt-get install -y curl wget
    chmod +x ~/ha-chromium-kiosk-setup.sh
"

echo -e "${GREEN}✓ Prerequisites installed${NC}"
echo -e "${BLUE}Step 6: Running HA Chromium Kiosk installation...${NC}"

# Create an expect script to automate the installation
cat > /tmp/kiosk_install.exp << EOF
#!/usr/bin/expect -f
set timeout -1
spawn ssh -o StrictHostKeyChecking=no debian@$VM_IP "sudo ./ha-chromium-kiosk-setup.sh install"

# Handle the banner
expect "Press*to continue"
send "\r"

# Handle user creation prompt if it appears
expect {
    "Do you want to use the existing user*" {
        send "Y\r"
        exp_continue
    }
    "Enter the IP address of your Home Assistant instance*" {
        send "$HA_IP\r"
    }
}

# Handle HA port
expect "Enter the port for Home Assistant*"
send "$HA_PORT\r"

# Handle dashboard path
expect "Enter the path to your Home Assistant dashboard*"
send "$HA_DASHBOARD_PATH\r"

# Handle kiosk mode
expect "Do you want to enable kiosk mode*"
send "Y\r"

# Handle mouse cursor
expect "Do you want to hide the mouse cursor*"
send "Y\r"

# Wait for completion
expect "Installation completed successfully"
EOF

chmod +x /tmp/kiosk_install.exp

# Run the expect script
if command -v expect &>/dev/null; then
    /tmp/kiosk_install.exp
else
    echo -e "${YELLOW}Warning: 'expect' command not found. Installation will not be automated.${NC}"
    echo -e "${YELLOW}Please manually complete the installation by running:${NC}"
    echo -e "ssh -o StrictHostKeyChecking=no debian@$VM_IP \"sudo ./ha-chromium-kiosk-setup.sh install\""
    exit 1
fi

echo -e "${GREEN}✓ HA Chromium Kiosk installation completed${NC}"
echo -e "${BLUE}Step 7: Rebooting VM to test auto-start...${NC}"

# Reboot the VM
ssh -o StrictHostKeyChecking=no "debian@$VM_IP" "sudo reboot"

# Wait for VM to reboot
echo "Waiting for VM to reboot..."
sleep 30

# Wait for SSH to become available again
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -ne "Attempt $ATTEMPT/$MAX_ATTEMPTS: Checking SSH connectivity after reboot...\r"

    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "debian@$VM_IP" "echo SSH connection successful" &>/dev/null; then
        echo -e "\n${GREEN}✓ SSH connection re-established after reboot${NC}"
        break
    fi

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "\n${RED}Error: Could not re-establish SSH connection after reboot${NC}"
        exit 1
    fi

    sleep 5
done

echo -e "${BLUE}Step 8: Verifying kiosk service is running...${NC}"

# Check if the service is running
SERVICE_STATUS=$(ssh -o StrictHostKeyChecking=no "debian@$VM_IP" "sudo systemctl is-active ha-chromium-kiosk.service")

if [ "$SERVICE_STATUS" = "active" ]; then
    echo -e "${GREEN}✓ HA Chromium Kiosk service is running${NC}"
else
    echo -e "${RED}✗ HA Chromium Kiosk service is not running (status: $SERVICE_STATUS)${NC}"
    echo -e "${YELLOW}Checking service logs:${NC}"
    ssh -o StrictHostKeyChecking=no "debian@$VM_IP" "sudo journalctl -u ha-chromium-kiosk.service -n 20"
fi

echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "  VM IP:        ${GREEN}$VM_IP${NC}"
echo -e "  VM ID:        ${GREEN}$VM_ID${NC}"
echo -e "  Service:      ${GREEN}$SERVICE_STATUS${NC}"
echo
echo -e "${YELLOW}To access the VM:${NC}"
echo -e "  ssh -o StrictHostKeyChecking=no debian@$VM_IP"
echo
echo -e "${YELLOW}To check the service status:${NC}"
echo -e "  ssh -o StrictHostKeyChecking=no debian@$VM_IP \"sudo systemctl status ha-chromium-kiosk.service\""
echo
echo -e "${YELLOW}To view service logs:${NC}"
echo -e "  ssh -o StrictHostKeyChecking=no debian@$VM_IP \"sudo journalctl -u ha-chromium-kiosk.service\""
echo
echo -e "${BLUE}Test completed.${NC}"
