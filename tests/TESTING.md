# Testing HA-Chromium-Kiosk

This document explains how to test the HA-Chromium-Kiosk setup script using the provided testing tools.

## Overview

The testing framework consists of:

1. **qemu-test-kiosk.sh**: Creates and manages a QEMU VM for testing (works on both Linux and macOS)
2. **test-kiosk-script.sh**: Creates and manages a VirtualBox VM for testing
3. **run-kiosk-tests.sh**: Automates various test scenarios
4. **kiosk-test-plan.md**: Outlines test cases and expected results

## Prerequisites

- QEMU installed on your system
  - On macOS: `brew install qemu`
  - On Linux: `sudo apt-get install qemu-system-x86`
- VirtualBox (if using the VirtualBox test script)
- Bash shell
- Internet connection (to download Debian cloud images)
- Sufficient disk space (~20GB for VM)

## Testing with Virtual Machines

### Setting up the Test Environment

#### Using QEMU (works on both Linux and macOS):

1. Set up the VM disk and download the pre-built Debian cloud image:

```bash
./tests/qemu-test-kiosk.sh setup
```

2. Start the VM for the first time:

```bash
./tests/qemu-test-kiosk.sh first-boot
```

Note: The script automatically detects your operating system. On macOS, it uses software emulation (TCG) instead of hardware acceleration, which may result in slower performance but works without KVM. On Linux, it uses KVM for better performance.

#### Using VirtualBox:

1. Set up the VM and download the pre-built Debian cloud image:

```bash
./tests/test-kiosk-script.sh setup
```

#### Common Steps:

These steps will:
- Download a pre-built Debian nocloud image if not already present (this image allows passwordless root login)
- Prepare a VM disk image based on the cloud image
- Start the VM with the pre-built Debian system
- Forward SSH to port 2222 on your host machine (for QEMU)

3. Log in to the VM:
   - For both QEMU and VirtualBox with nocloud image: username `root` with no password (passwordless login)
   - **Note**: You'll need to log in through the VM console window that opens when you start the VM

4. Set up SSH access (optional but recommended):

```bash
# Generate an SSH setup script on your host machine
./tests/qemu-test-kiosk.sh ssh-setup

# In the VM console, create a file with the same content as the generated script
# Then make it executable and run it
chmod +x ssh-setup.sh
./ssh-setup.sh
```

5. After setting up SSH, you can connect from your host machine:

```bash
# Connect with the password 'kiosk' (if you used the ssh-setup script)
ssh -p 2222 root@localhost
```

6. Prepare the VM for testing:

```bash
# Update the system
apt-get update && apt-get upgrade -y

# Install git and bash (if not already installed)
apt-get install -y git bash

# Clone the repository
git clone https://github.com/kunaalm/HA-Chromium-Kiosk.git

# Navigate to the repository directory
cd HA-Chromium-Kiosk

# Make the script executable
chmod +x ha-chromium-kiosk-setup.sh
```

7. Create a snapshot of the clean VM state (use the appropriate script for your OS):

```bash
# For both Linux and macOS
./tests/qemu-test-kiosk.sh snapshot
```

### Running Tests

#### Manual Testing

Follow the test cases outlined in `kiosk-test-plan.md`.

**First-time testing:**
1. Set up the VM as described in the "Setting up the Test Environment" section
2. Install and configure the necessary components in the VM
3. Create a clean snapshot before running any tests:
```bash
./tests/qemu-test-kiosk.sh snapshot
```

**For each subsequent test:**
1. Start with a clean state by reverting to the snapshot:
```bash
./tests/qemu-test-kiosk.sh revert
```
2. Start the VM:
```bash
./tests/qemu-test-kiosk.sh start
```
3. Run the specific test case
4. Document the results

#### Automated Testing

The `run-kiosk-tests.sh` script automates some of the test scenarios:

```bash
# Run all automated tests
./tests/run-kiosk-tests.sh all

# Prepare the test environment
./tests/run-kiosk-tests.sh prepare

# Clean up after testing
./tests/run-kiosk-tests.sh cleanup
```

## Test Cases

See `kiosk-test-plan.md` for detailed test cases and expected results.

## Tips for Effective Testing

1. **Snapshot Management**: Create snapshots at different stages of testing to easily revert to specific states.

2. **Network Configuration**: Test with different network configurations:
   - Connected to the internet
   - Disconnected from the internet
   - Connected to a local network with Home Assistant

3. **Error Simulation**: Deliberately introduce errors to test error handling:
   - Provide invalid IP addresses
   - Create conflicting configurations
   - Interrupt the script during execution

4. **Documentation**: Keep detailed notes of test results, including:
   - Screenshots
   - Error messages
   - Unexpected behavior

## Troubleshooting

### VM Issues

- **VM fails to start**: Ensure QEMU or VirtualBox is properly installed and has sufficient permissions
- **Network connectivity issues**: Check VM network settings
- **Snapshot errors**: Delete corrupted snapshots and create new ones
- **KVM errors on macOS**: Use the macOS-specific script which uses software emulation instead
- **Cloud image download fails**: Check your internet connection or try downloading the image manually from http://cloud.debian.org/images/cloud/bookworm/latest/
- **Image conversion errors**: For VirtualBox, ensure you have sufficient permissions to convert the image format

### Script Testing Issues

- **Permission denied**: Ensure scripts are executable (`chmod +x script.sh`)
- **Dependency errors**: Make sure all required packages are installed in the VM
- **Path issues**: Run scripts from the repository root directory
- **Shell issues**: Always run the script with bash explicitly (`bash ./ha-chromium-kiosk-setup.sh install`) as the default shell in the Debian cloud image might not be bash
- **SSH connection issues**: Remember that SSH is not installed by default in the Debian cloud image. Use the `ssh-setup` command to generate a setup script or follow the manual SSH setup instructions
