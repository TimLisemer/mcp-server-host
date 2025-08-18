# Multi-stage build for MCP server host
FROM ubuntu:22.04 AS base

# Install common dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    supervisor \
    python3 \
    python3-pip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Install Go 1.21
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz && \
    rm go1.21.5.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"
ENV GOPATH="/root/go"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install rust-analyzer for Rust LSP support
RUN rustup component add rust-src rust-analyzer

# Create app directory structure
WORKDIR /app
RUN mkdir -p /app/servers /app/config /app/scripts /app/data /workspace /var/log/mcp

# Copy configuration and scripts
COPY config/ /app/config/
COPY scripts/ /app/scripts/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/scripts/*.sh /app/entrypoint.sh

# Install MCP servers
RUN /app/scripts/install-servers.sh

# Expose workspace volume
VOLUME ["/workspace", "/app/data", "/var/log"]

# Set environment variables
ENV LOG_LEVEL=info
ENV WORKSPACE_PATH=/workspace
ENV MCP_SERVERS_CONFIG=/app/config/servers.json

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /app/scripts/health-check.sh || exit 1

# Entry point
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]