#!/bin/bash
###################################################################################
# HA Chromium Kiosk Docker Test Script
# This script sets up a Docker container to test the HA-Chromium-Kiosk setup script
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

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_message "$RED" "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_message "$GREEN" "Docker is installed."
}

# Function to build the Docker image
build_image() {
    print_message "$YELLOW" "Building Docker image for testing..."
    docker build -t ha-kiosk-test .
    print_message "$GREEN" "Docker image built successfully."
}

# Function to run the Docker container
run_container() {
    print_message "$YELLOW" "Running Docker container for testing..."
    docker run -it --name ha-kiosk-test-container ha-kiosk-test
}

# Function to run tests in the Docker container
run_tests() {
    print_message "$YELLOW" "Running tests in Docker container..."
    docker exec -it ha-kiosk-test-container bash -c "cd /app && ./run-kiosk-tests.sh all"
}

# Function to clean up Docker resources
cleanup() {
    print_message "$YELLOW" "Cleaning up Docker resources..."
    docker stop ha-kiosk-test-container 2>/dev/null || true
    docker rm ha-kiosk-test-container 2>/dev/null || true
    print_message "$GREEN" "Cleanup complete."
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Test the HA-Chromium-Kiosk setup script in a Docker container."
    echo ""
    echo "Options:"
    echo "  build       Build the Docker image"
    echo "  run         Run the Docker container"
    echo "  test        Run tests in the Docker container"
    echo "  clean       Clean up Docker resources"
    echo "  all         Build, run, and test in one command"
    echo "  help        Display this help message"
    echo ""
}

# Main script
case "$1" in
    build)
        check_docker
        build_image
        ;;
    run)
        check_docker
        run_container
        ;;
    test)
        check_docker
        run_tests
        ;;
    clean)
        check_docker
        cleanup
        ;;
    all)
        check_docker
        build_image
        cleanup
        run_container
        ;;
    help|*)
        show_help
        ;;
esac
