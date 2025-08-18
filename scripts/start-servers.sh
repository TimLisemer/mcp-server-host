#!/bin/bash
set -e

CONFIG_FILE="${MCP_SERVERS_CONFIG:-/app/config/servers.json}"
SUPERVISOR_CONF="/etc/supervisor/conf.d/mcp-servers.conf"
SERVERS_DIR="/app/servers"

echo "Generating supervisor configuration for MCP servers..."

# Start with empty supervisor config
echo "# Auto-generated MCP server configurations" > "$SUPERVISOR_CONF"
echo "# Generated at $(date)" >> "$SUPERVISOR_CONF"
echo "" >> "$SUPERVISOR_CONF"

# Parse servers configuration
servers=$(jq -r '.servers | to_entries[] | select(.value.enabled == true) | @json' "$CONFIG_FILE")

server_count=0
while IFS= read -r server_json; do
    server=$(echo "$server_json" | jq -r '.')
    name=$(echo "$server" | jq -r '.key')
    value=$(echo "$server" | jq -r '.value')
    
    type=$(echo "$value" | jq -r '.type')
    binary_path=$(echo "$value" | jq -r '.binary_path')
    install_path=$(echo "$value" | jq -r '.install_path // ""')
    default_args=$(echo "$value" | jq -r '.default_args[]? // ""' | tr '\n' ' ')
    
    server_dir="$SERVERS_DIR/$name"
    
    # Determine the command based on type and paths
    if [ -n "$install_path" ] && [ "$install_path" != "null" ]; then
        # Use install path if specified
        command="$install_path"
    else
        # Build command based on type
        case "$type" in
            "node")
                if [ -f "$server_dir/dist/index.js" ]; then
                    command="node $server_dir/dist/index.js"
                elif [ -f "$server_dir/index.js" ]; then
                    command="node $server_dir/index.js"
                elif [ -f "$server_dir/src/index.js" ]; then
                    command="node $server_dir/src/index.js"
                else
                    echo "Warning: No entry point found for $name"
                    continue
                fi
                ;;
            "go")
                if [ -f "$server_dir/$binary_path" ]; then
                    command="$server_dir/$binary_path"
                elif [ -f "/root/go/bin/$(basename $binary_path)" ]; then
                    command="/root/go/bin/$(basename $binary_path)"
                else
                    echo "Warning: Binary not found for $name"
                    continue
                fi
                ;;
            "rust")
                if [ -f "$server_dir/$binary_path" ]; then
                    command="$server_dir/$binary_path"
                else
                    echo "Warning: Binary not found for $name"
                    continue
                fi
                ;;
            "python")
                if [ -f "$server_dir/main.py" ]; then
                    command="python3 $server_dir/main.py"
                else
                    echo "Warning: No entry point found for $name"
                    continue
                fi
                ;;
            *)
                echo "Warning: Unknown type $type for $name"
                continue
                ;;
        esac
    fi
    
    # Add default arguments if any
    if [ -n "$default_args" ] && [ "$default_args" != "null" ]; then
        command="$command $default_args"
    fi
    
    # Write supervisor program configuration
    cat >> "$SUPERVISOR_CONF" << ENDCONFIG
[program:mcp-$name]
command=$command
directory=$server_dir
autostart=true
autorestart=true
startretries=3
stderr_logfile=/var/log/mcp/$name.err.log
stdout_logfile=/var/log/mcp/$name.out.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
stdout_logfile_backups=2
stderr_logfile_backups=2
environment=PATH="/usr/local/go/bin:/root/go/bin:/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",GOPATH="/root/go",NODE_ENV="production",LOG_LEVEL="info"
user=root

ENDCONFIG
    
    ((server_count++))
    echo "  Configured $name"
done <<< "$servers"

echo ""
echo "Generated supervisor configuration for $server_count servers"
echo "Configuration saved to: $SUPERVISOR_CONF"