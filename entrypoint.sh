#!/bin/bash
set -e

echo "Starting MCP Server Host..."
echo "----------------------------------------"
echo "LOG_LEVEL: ${LOG_LEVEL:-info}"
echo "WORKSPACE_PATH: ${WORKSPACE_PATH}"
echo "CONFIG_PATH: ${MCP_SERVERS_CONFIG}"
echo "----------------------------------------"

# Ensure directories exist
mkdir -p /workspace /app/data /var/log/mcp /var/run /var/log/supervisor

# Generate supervisor configuration from servers.json
echo "Generating supervisor configuration..."
/app/scripts/start-servers.sh

# Verify supervisor config
if [ ! -f /etc/supervisor/conf.d/mcp-servers.conf ]; then
    echo "Warning: No MCP servers configured"
fi

# Start supervisor
echo "Starting supervisor..."
exec "$@"