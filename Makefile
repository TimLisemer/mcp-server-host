.PHONY: help build start stop restart logs health status clean rebuild ssh-test shell update-config

# Default target
help:
	@echo "MCP Server Host - Management Commands"
	@echo "====================================="
	@echo ""
	@echo "Basic Commands:"
	@echo "  make build        - Build the Docker image"
	@echo "  make start        - Start the container"
	@echo "  make stop         - Stop the container"
	@echo "  make restart      - Restart the container"
	@echo "  make rebuild      - Rebuild and restart everything"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs         - View container logs"
	@echo "  make health       - Check health status"
	@echo "  make status       - Show server status"
	@echo ""
	@echo "Development:"
	@echo "  make shell        - Open shell in container"
	@echo "  make ssh-test     - Test SSH connectivity"
	@echo "  make update-config - Update server configuration"
	@echo "  make clean        - Remove container and volumes"
	@echo ""

# Build the Docker image
build:
	@echo "Building MCP Server Host image..."
	docker-compose build
	@echo "Build complete!"

# Start the container
start:
	@echo "Starting MCP Server Host..."
	docker-compose up -d
	@sleep 5
	@make status

# Stop the container
stop:
	@echo "Stopping MCP Server Host..."
	docker-compose down
	@echo "Container stopped"

# Restart the container
restart: stop start

# View logs
logs:
	docker-compose logs -f --tail=100

# Check health status
health:
	@echo "Checking health status..."
	@docker exec mcp-server-host /app/scripts/health-check.sh || echo "Health check failed"

# Show server status
status:
	@echo "MCP Server Status:"
	@echo "=================="
	@docker exec mcp-server-host supervisorctl status 2>/dev/null || echo "Container not running or no servers configured"

# Clean everything
clean:
	@echo "Cleaning up..."
	docker-compose down -v
	@echo "Cleanup complete"

# Rebuild everything
rebuild: clean build start

# Test SSH connectivity
ssh-test:
	@echo "Testing SSH connectivity to MCP servers..."
	@echo ""
	@echo "Example command to test language server:"
	@echo "ssh tim@tim-server 'docker exec mcp-server-host /root/go/bin/mcp-language-server --help'"
	@echo ""
	@echo "Testing connection..."
	ssh tim@localhost "docker exec mcp-server-host echo 'SSH connection successful!'" || echo "SSH test failed - check your SSH configuration"

# Open shell in container
shell:
	docker exec -it mcp-server-host /bin/bash

# Update server configuration without rebuilding
update-config:
	@echo "Updating server configuration..."
	docker exec mcp-server-host /app/scripts/start-servers.sh
	docker exec mcp-server-host supervisorctl reread
	docker exec mcp-server-host supervisorctl update
	@make status

# Show container information
info:
	@echo "Container Information:"
	@echo "====================="
	@docker ps -a | grep mcp-server-host || echo "Container not found"
	@echo ""
	@echo "Image Information:"
	@docker images | grep mcp-server-host || echo "Image not found"
	@echo ""
	@echo "Network Information:"
	@docker inspect mcp-server-host 2>/dev/null | jq -r '.[0].NetworkSettings.Networks' || echo "Container not running"

# View supervisor logs
supervisor-logs:
	docker exec mcp-server-host tail -n 50 /var/log/supervisor/supervisord.log

# View specific server logs
server-logs:
	@read -p "Enter server name (e.g., language-server): " server; \
	docker exec mcp-server-host tail -n 100 /var/log/mcp/$$server.out.log 2>/dev/null || echo "Server logs not found"

# Quick install for development
dev: build start logs

# Production deployment
deploy: rebuild
	@echo "Deployment complete!"
	@echo "Add the following to your Claude Desktop configuration:"
	@echo ""
	@cat examples/claude-config.json 2>/dev/null || echo "See README for configuration examples"