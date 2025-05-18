FROM debian:12-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    bash \
    procps \
    xorg \
    openbox \
    chromium \
    xserver-xorg \
    xinit \
    unclutter \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser

# Set working directory
WORKDIR /app

# Copy the script and test files
COPY ha-chromium-kiosk-setup.sh /app/
COPY run-kiosk-tests.sh /app/
COPY kiosk-test-plan.md /app/
COPY TESTING.md /app/

# Make scripts executable
RUN chmod +x /app/ha-chromium-kiosk-setup.sh /app/run-kiosk-tests.sh

# Switch to test user
USER testuser

# Default command
CMD ["/bin/bash"]
