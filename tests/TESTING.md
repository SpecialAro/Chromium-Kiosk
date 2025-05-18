# Testing HA-Chromium-Kiosk

This document explains how to test the HA-Chromium-Kiosk setup script using the provided testing tools.

## Overview

The testing framework consists of:

1. **qemu-test-kiosk.sh**: Creates and manages a QEMU VM for testing (Linux)
2. **qemu-test-kiosk-mac.sh**: macOS-specific version of the QEMU testing script
3. **run-kiosk-tests.sh**: Automates various test scenarios
4. **kiosk-test-plan.md**: Outlines test cases and expected results

## Prerequisites

- QEMU installed on your system
  - On macOS: `brew install qemu`
  - On Linux: `sudo apt-get install qemu-system-x86`
- Bash shell
- Internet connection (to download Debian ISO)
- Sufficient disk space (~20GB for VM)

## Testing with QEMU VM

### Setting up the Test Environment

#### On Linux:

1. Set up the VM disk and download the ISO:

```bash
./tests/qemu-test-kiosk.sh setup
```

2. Start the VM with the installation media:

```bash
./tests/qemu-test-kiosk.sh install
```

#### On macOS:

1. Set up the VM disk and download the ISO:

```bash
./tests/qemu-test-kiosk-mac.sh setup
```

2. Start the VM with the installation media:

```bash
./tests/qemu-test-kiosk-mac.sh install
```

The macOS script uses software emulation (TCG) instead of hardware acceleration, which may result in slower performance but works without KVM.

#### Common Steps:

These steps will:
- Download a Debian ISO if not already present
- Create a new QEMU disk image
- Start the VM with the Debian installer
- Forward SSH to port 2222 on your host machine

3. Complete the Debian installation in the VM:
   - Install a minimal system without desktop environment
   - Create a user (e.g., username: test, password: test)
   - When asked for software selection, only select "SSH server" and "standard system utilities"

4. After installation, start the VM and log in (use the appropriate script for your OS):

```bash
# On Linux
./tests/qemu-test-kiosk.sh start

# On macOS
./tests/qemu-test-kiosk-mac.sh start
```

5. Connect to the VM via SSH:

```bash
ssh -p 2222 test@localhost
```

6. Prepare the VM for testing:

```bash
# Update the system
sudo apt-get update && sudo apt-get upgrade -y

# Install git
sudo apt-get install -y git

# Clone the repository
git clone https://github.com/kunaalm/HA-Chromium-Kiosk.git

# Navigate to the repository directory
cd HA-Chromium-Kiosk
```

7. Create a snapshot of the clean VM state (use the appropriate script for your OS):

```bash
# On Linux
./tests/qemu-test-kiosk.sh snapshot

# On macOS
./tests/qemu-test-kiosk-mac.sh snapshot
```

### Running Tests

#### Manual Testing

Follow the test cases outlined in `kiosk-test-plan.md`. For each test:

1. Revert to the clean snapshot (use the appropriate script for your OS):

```bash
# On Linux
./tests/qemu-test-kiosk.sh revert

# On macOS
./tests/qemu-test-kiosk-mac.sh revert
```

2. Run the specific test case
3. Document the results

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

- **VM fails to start**: Ensure QEMU is properly installed and has sufficient permissions
- **Network connectivity issues**: Check QEMU network settings
- **Snapshot errors**: Delete corrupted snapshots and create new ones
- **KVM errors on macOS**: Use the macOS-specific script which uses software emulation instead

### Script Testing Issues

- **Permission denied**: Ensure scripts are executable (`chmod +x script.sh`)
- **Dependency errors**: Make sure all required packages are installed in the VM
- **Path issues**: Run scripts from the repository root directory
