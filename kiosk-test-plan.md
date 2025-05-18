# HA-Chromium-Kiosk Test Plan

This document outlines the test plan for the HA-Chromium-Kiosk setup script using a virtual machine environment.

## Test Environment

- VirtualBox VM running Debian 12
- 2GB RAM, 2 CPU cores, 20GB disk
- Clean installation without desktop environment

## Test Scenarios

### 1. Basic Installation Test

**Objective**: Verify that the script can successfully install the kiosk environment on a clean system.

**Steps**:
1. Start with a clean VM (use `./test-kiosk-script.sh revert` to restore snapshot)
2. Run the installation script: `sudo ./ha-chromium-kiosk-setup.sh install`
3. Provide the following inputs:
   - Home Assistant IP: `192.168.1.100` (or your actual HA instance IP)
   - Port: `8123` (default)
   - Dashboard path: `lovelace/default_view` (default)
   - Enable kiosk mode: `Y` (default)
   - Hide cursor: `Y` (default)
4. Choose to reboot: `Y`

**Expected Result**: 
- Script completes without errors
- System reboots and automatically logs in as the kiosk user
- Chromium starts in kiosk mode and attempts to connect to the specified Home Assistant instance

### 2. Configuration Conflict Test

**Objective**: Verify that the script properly handles existing configurations.

**Steps**:
1. Start with a clean VM
2. Create a kiosk user manually: `sudo adduser kiosk`
3. Create some configuration files:
   ```bash
   sudo mkdir -p /home/kiosk/.config/openbox
   echo "# Custom configuration" | sudo tee /home/kiosk/.config/openbox/autostart
   sudo chown -R kiosk:kiosk /home/kiosk/.config
   ```
4. Run the installation script: `sudo ./ha-chromium-kiosk-setup.sh install`
5. Choose to use the existing kiosk user
6. When prompted about existing configurations, choose to back them up

**Expected Result**:
- Script detects existing configuration files
- Script offers to backup existing configurations
- Backups are created with timestamps
- Installation completes successfully

### 3. Uninstallation Test

**Objective**: Verify that the script can properly uninstall the kiosk environment.

**Steps**:
1. Start with a VM where the kiosk has been installed
2. Run the uninstallation script: `sudo ./ha-chromium-kiosk-setup.sh uninstall`
3. Confirm uninstallation: `Y`
4. Choose to remove installed packages: `Y`

**Expected Result**:
- Script removes all configurations and installed packages
- System returns to its pre-installation state

### 4. Backup and Restore Test

**Objective**: Verify that the backup and restore functionality works correctly.

**Steps**:
1. Start with a VM where the kiosk has been installed
2. Run the uninstallation script: `sudo ./ha-chromium-kiosk-setup.sh uninstall`
3. When prompted about restoring backups, choose to restore them: `Y`

**Expected Result**:
- Script detects backup files
- Script offers to restore backups
- Original configurations are restored

### 5. Network Connectivity Test

**Objective**: Verify that the script handles network connectivity issues gracefully.

**Steps**:
1. Start with a clean VM
2. Disconnect the VM from the network (in VirtualBox, go to Settings > Network and temporarily disable the adapter)
3. Run the installation script: `sudo ./ha-chromium-kiosk-setup.sh install`
4. Provide an unreachable Home Assistant IP

**Expected Result**:
- Script should handle network connectivity issues gracefully
- The kiosk should attempt to connect to Home Assistant and retry when connectivity is restored

## Test Execution Checklist

| Test Case | Status | Notes |
|-----------|--------|-------|
| 1. Basic Installation | | |
| 2. Configuration Conflict | | |
| 3. Uninstallation | | |
| 4. Backup and Restore | | |
| 5. Network Connectivity | | |

## Additional Test Notes

- For each test, take screenshots or record the terminal output to document the results
- Note any unexpected behavior or error messages
- Test with different versions of Debian if possible (10, 11, 12)
- Test with different Home Assistant configurations (local, remote, with/without SSL)
