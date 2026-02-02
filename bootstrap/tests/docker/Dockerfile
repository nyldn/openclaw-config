FROM debian:12-slim

# Install minimum prerequisites
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    bash \
    openssh-server \
    iputils-ping \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Create non-root test user with passwordless sudo
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up SSH directory (required for security module testing)
RUN mkdir -p /var/run/sshd && \
    mkdir -p /home/testuser/.ssh && \
    chown testuser:testuser /home/testuser/.ssh

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Default command
CMD ["/bin/bash"]
