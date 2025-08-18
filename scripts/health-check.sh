#!/bin/bash

# Health check script for MCP server host
set -e

# Check if supervisor is running
if ! pgrep -x "supervisord" > /dev/null; then
    echo "ERROR: Supervisor is not running"
    exit 1
fi

# Check supervisor socket
if [ ! -S /var/run/supervisor.sock ]; then
    echo "ERROR: Supervisor socket not found"
    exit 1
fi

# Get status of all programs
status=$(supervisorctl status 2>/dev/null || true)

# Check if we have any programs
if [ -z "$status" ]; then
    echo "WARNING: No MCP servers configured"
    # This is not necessarily an error, container might be waiting for configuration
    exit 0
fi

# Count running and failed programs
running_count=0
failed_count=0
total_count=0

while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    
    ((total_count++))
    
    if echo "$line" | grep -q "RUNNING"; then
        ((running_count++))
    elif echo "$line" | grep -q "FATAL\|FAILED\|STOPPED"; then
        ((failed_count++))
        echo "WARNING: $line"
    fi
done <<< "$status"

# Report status
echo "MCP Server Status: $running_count/$total_count running"

# If more than half of the servers are failed, consider unhealthy
if [ "$total_count" -gt 0 ] && [ "$failed_count" -gt $((total_count / 2)) ]; then
    echo "ERROR: Too many failed servers ($failed_count/$total_count)"
    exit 1
fi

# Check disk space
available_space=$(df /app | awk 'NR==2 {print $4}')
if [ "$available_space" -lt 100000 ]; then  # Less than 100MB
    echo "WARNING: Low disk space: ${available_space}KB available"
fi

# Check memory usage
mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ "$mem_usage" -gt 90 ]; then
    echo "WARNING: High memory usage: ${mem_usage}%"
fi

echo "Health check passed"
exit 0