# Testing HA Chromium Kiosk on Proxmox

This guide explains how to test the HA Chromium Kiosk setup on a Proxmox virtual environment. This is useful for testing the script in a controlled environment before deploying it to production hardware.

## Prerequisites

Before you begin, you'll need:

1. **A Proxmox server** with:
   - SSH access with privileges to create and manage VMs
   - Sufficient resources to run a Debian VM (2GB RAM, 2 CPU cores recommended)

2. **A Debian cloud image** uploaded to your Proxmox server:
   - Debian 11 (Bullseye) or newer recommended
   - Cloud-init enabled image

3. **SSH key** for passwordless access to the VM

4. **A running Home Assistant instance** that is accessible from the Proxmox network

5. **Required tools** on your local machine:
   - SSH client
   - `expect` command (for automated installation)

## Setting Up Debian Cloud Image on Proxmox

If you don't already have a Debian cloud image on your Proxmox server, follow these steps:

1. **Download a Debian cloud image**:
   ```bash
   wget https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2
   ```

2. **Upload the image to your Proxmox server**:
   ```bash
   scp debian-11-generic-amd64.qcow2 root@your-proxmox-host:/var/lib/vz/template/iso/
   ```

## Using the Test Script

The `proxmox-test-kiosk.sh` script automates the process of creating a VM, installing the HA Chromium Kiosk, and verifying its functionality.

### Basic Usage

```bash
./proxmox-test-kiosk.sh --host proxmox.example.com --id 100 --template debian-11-generic-amd64.qcow2 --ha-ip 192.168.1.100
```

### All Available Options

```
Options:
  -h, --host HOST       Proxmox host address (required)
  -u, --user USER       Proxmox user (default: root)
  -n, --node NODE       Proxmox node (default: pve)
  -i, --id ID           VM ID to use (required)
  -t, --template TMPL   Debian template to use (required)
  -m, --memory MEM      VM memory in MB (default: 2048)
  -c, --cores CORES     VM CPU cores (default: 2)
  -s, --storage STORE   VM storage location (default: local-lvm)
  -k, --key KEY         SSH public key path (default: ~/.ssh/id_rsa.pub)
  -a, --ha-ip IP        Home Assistant IP address (required)
  -p, --ha-port PORT    Home Assistant port (default: 8123)
  --help                Display this help message
```

### Example with All Options

```bash
./proxmox-test-kiosk.sh \
  --host proxmox.example.com \
  --user root \
  --node pve \
  --id 100 \
  --template debian-11-generic-amd64.qcow2 \
  --memory 4096 \
  --cores 4 \
  --storage local-lvm \
  --key ~/.ssh/id_rsa.pub \
  --ha-ip 192.168.1.100 \
  --ha-port 8123
```

## What the Test Script Does

The script performs the following steps:

1. **Creates a VM** on your Proxmox server using the specified template
2. **Configures cloud-init** with SSH key for passwordless access
3. **Waits for the VM** to boot and obtain an IP address
4. **Copies the HA Chromium Kiosk script** to the VM
5. **Installs prerequisites** on the VM
6. **Runs the HA Chromium Kiosk installation** with automated responses
7. **Reboots the VM** to test auto-start functionality
8. **Verifies the kiosk service** is running correctly
9. **Provides a summary** of the test results

## Manual Testing After Deployment

After the script completes, you can manually test the VM:

1. **SSH into the VM**:
   ```bash
   ssh debian@VM_IP_ADDRESS
   ```

2. **Check service status**:
   ```bash
   sudo systemctl status ha-chromium-kiosk.service
   ```

3. **View service logs**:
   ```bash
   sudo journalctl -u ha-chromium-kiosk.service
   ```

4. **Test VNC access** (if your Proxmox setup supports it):
   - Access the Proxmox web interface
   - Navigate to the VM
   - Open the console to see the kiosk display

## Troubleshooting

### VM Creation Issues

If the VM fails to create:
- Check if you have sufficient permissions on the Proxmox server
- Verify the template path is correct
- Ensure you have enough storage space available

### SSH Connection Issues

If SSH connection fails:
- Check if the VM has properly booted
- Verify network connectivity between your machine and the VM
- Ensure your SSH key is correctly specified

### Installation Issues

If the kiosk installation fails:
- Check the installation logs on the VM
- Verify that the Home Assistant instance is reachable from the VM
- Ensure all required packages can be installed (internet connectivity)

### Service Not Starting

If the kiosk service doesn't start:
- Check the service logs: `sudo journalctl -u ha-chromium-kiosk.service`
- Verify X server configuration: `sudo Xorg -configure`
- Check if all dependencies are installed correctly

## Cleaning Up

To remove the test VM when you're done:

```bash
ssh root@your-proxmox-host "qm stop VM_ID && qm destroy VM_ID"
```

Replace `VM_ID` with the ID you used when creating the VM.

## Advanced Testing

### Testing with Different Debian Versions

You can test with different Debian versions by using different cloud images:

- Debian 10 (Buster): `debian-10-generic-amd64.qcow2`
- Debian 11 (Bullseye): `debian-11-generic-amd64.qcow2`
- Debian 12 (Bookworm): `debian-12-generic-amd64.qcow2`

### Testing with Different Hardware Configurations

Modify the VM hardware parameters to test different configurations:

```bash
./proxmox-test-kiosk.sh --host proxmox.example.com --id 100 --template debian-11-generic-amd64.qcow2 --ha-ip 192.168.1.100 --memory 1024 --cores 1
```

This tests with minimal resources (1GB RAM, 1 CPU core).

### Testing Uninstallation

To test the uninstallation process:

1. SSH into the VM:
   ```bash
   ssh debian@VM_IP_ADDRESS
   ```

2. Run the uninstallation:
   ```bash
   sudo ./ha-chromium-kiosk-setup.sh uninstall
   ```

3. Verify that all components have been removed correctly.
