#!/bin/bash
###################################################################################
# HA Chromium Kiosk Test Runner
# This script automates testing of the HA-Chromium-Kiosk setup script
###################################################################################

set -e

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

# Function to run a test and log results
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_exit_code=${3:-0}
    
    print_message "$YELLOW" "Running test: $test_name"
    echo "Command: $test_command"
    echo "----------------------------------------"
    
    # Create log directory if it doesn't exist
    mkdir -p test_logs
    
    # Run the command and capture output and exit code
    eval "$test_command" > "test_logs/${test_name}.log" 2>&1
    local exit_code=$?
    
    # Check if the exit code matches the expected exit code
    if [ $exit_code -eq $expected_exit_code ]; then
        print_message "$GREEN" "✓ Test passed: $test_name (Exit code: $exit_code)"
    else
        print_message "$RED" "✗ Test failed: $test_name (Exit code: $exit_code, expected: $expected_exit_code)"
    fi
    
    echo "Log file: test_logs/${test_name}.log"
    echo "----------------------------------------"
}

# Function to prepare test environment
prepare_test_environment() {
    print_message "$YELLOW" "Preparing test environment..."
    
    # Create a backup of the original script
    if [ ! -f "ha-chromium-kiosk-setup.sh.original" ]; then
        cp "ha-chromium-kiosk-setup.sh" "ha-chromium-kiosk-setup.sh.original"
    fi
    
    print_message "$GREEN" "Test environment prepared."
}

# Function to simulate existing configurations
create_existing_configs() {
    print_message "$YELLOW" "Creating existing configurations for testing..."
    
    # Create kiosk user if it doesn't exist
    if ! id "kiosk" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" kiosk
    fi
    
    # Create test configuration files
    sudo mkdir -p /home/kiosk/.config/openbox
    echo "# Existing Openbox configuration" | sudo tee /home/kiosk/.config/openbox/autostart > /dev/null
    sudo mkdir -p /home/kiosk/.config/ha-chromium-kiosk
    echo "# Existing kiosk configuration" | sudo tee /home/kiosk/.config/ha-chromium-kiosk/config > /dev/null
    sudo chown -R kiosk:kiosk /home/kiosk/.config
    
    # Create systemd service file
    sudo mkdir -p /etc/systemd/system
    cat <<EOF | sudo tee /etc/systemd/system/ha-chromium-kiosk.service > /dev/null
[Unit]
Description=Existing Chromium Kiosk Service
After=network.target

[Service]
ExecStart=/bin/echo "Existing service"

[Install]
WantedBy=multi-user.target
EOF
    
    print_message "$GREEN" "Existing configurations created."
}

# Function to clean up test environment
cleanup_test_environment() {
    print_message "$YELLOW" "Cleaning up test environment..."
    
    # Restore original script
    if [ -f "ha-chromium-kiosk-setup.sh.original" ]; then
        cp "ha-chromium-kiosk-setup.sh.original" "ha-chromium-kiosk-setup.sh"
    fi
    
    # Remove test user and configurations
    if id "kiosk" &>/dev/null; then
        sudo userdel -rf kiosk
    fi
    
    # Remove systemd service file
    sudo rm -f /etc/systemd/system/ha-chromium-kiosk.service
    
    print_message "$GREEN" "Test environment cleaned up."
}

# Function to run all tests
run_all_tests() {
    prepare_test_environment
    
    # Test 1: Basic syntax check
    run_test "syntax_check" "bash -n ha-chromium-kiosk-setup.sh"
    
    # Test 2: Help/usage display
    run_test "usage_display" "sudo ./ha-chromium-kiosk-setup.sh" 1
    
    # Test 3: Configuration conflict detection
    create_existing_configs
    run_test "config_conflict_detection" "echo -e 'Y\nY\n' | sudo ./ha-chromium-kiosk-setup.sh install" 1
    
    # Clean up
    cleanup_test_environment
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Run automated tests for the HA-Chromium-Kiosk setup script."
    echo ""
    echo "Options:"
    echo "  all         Run all tests"
    echo "  prepare     Prepare the test environment"
    echo "  cleanup     Clean up the test environment"
    echo "  help        Display this help message"
    echo ""
}

# Main script
case "$1" in
    all)
        run_all_tests
        ;;
    prepare)
        prepare_test_environment
        ;;
    cleanup)
        cleanup_test_environment
        ;;
    help|*)
        show_help
        ;;
esac
