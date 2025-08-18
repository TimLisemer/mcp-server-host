# MCP Server Host

A modular Docker container for hosting multiple MCP (Model Context Protocol) servers with remote SSH access support. Perfect for running MCP servers on a NixOS server or any Docker-compatible system.

## Features

- **Multi-Language Support**: Go, Rust, Node.js, Python (with virtual environments)
- **Modular Architecture**: Easy to add/remove servers via JSON configuration
- **Process Management**: Supervisor handles all MCP servers automatically
- **Remote Access**: SSH + docker exec integration for Claude Desktop
- **Health Monitoring**: Built-in health checks and logging
- **Virtual Environment Support**: Python servers run in isolated environments

## Quick Start

```bash
# Build and start the container
make build
make start

# Check status
make status

# View logs
make logs
```

## Project Structure

```
mcp-server-host/
├── Dockerfile                    # Ubuntu 25.04 with multi-language support
├── docker-compose.yml           # Container orchestration
├── Makefile                     # Management commands
├── entrypoint.sh               # Container startup script
├── supervisord.conf            # Process management configuration
├── config/
│   └── servers.json           # MCP server configuration
├── scripts/
│   ├── install-servers.sh     # Automated server installation
│   ├── start-servers.sh       # Dynamic supervisor config generation
│   └── health-check.sh        # Health monitoring
└── README.md                  # This file
```

## Currently Running Servers

### 1. MCP Language Server (Go)
- **Type**: Go-based LSP integration
- **Capabilities**: Rust, Go, Python, TypeScript language support via rust-analyzer
- **Repository**: [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server)
- **Binary Path**: `/root/go/bin/mcp-language-server`

### 2. MCP NixOS Server (Python)
- **Type**: Python-based NixOS package search
- **Capabilities**: NixOS package search, configuration assistance
- **Repository**: [utensils/mcp-nixos](https://github.com/utensils/mcp-nixos)
- **Virtual Environment**: `/app/servers/mcp-nixos/venv/`
- **Runtime**: Python 3.13 with isolated dependencies

## Claude Desktop Configuration

Configure Claude Desktop to use the remote MCP servers:

```json
{
  "mcpServers": {
    "language-server-rust": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "/root/go/bin/mcp-language-server",
        "--workspace", "/workspace/your-rust-project",
        "--lsp", "rust-analyzer"
      ]
    },
    "nixos-search": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "/app/servers/mcp-nixos/venv/bin/python3",
        "-m", "mcp_nixos.server"
      ]
    }
  }
}
```

## Configuration

### Current Server Configuration

The `config/servers.json` file contains our working servers:

```json
{
  "servers": {
    "mcp-language-server": {
      "enabled": true,
      "type": "go",
      "description": "MCP Language Server with Rust support via rust-analyzer",
      "repository": "https://github.com/isaacphi/mcp-language-server",
      "build_command": "go install github.com/isaacphi/mcp-language-server@latest",
      "binary_path": "/root/go/bin/mcp-language-server",
      "install_path": "/root/go/bin/mcp-language-server",
      "capabilities": ["lsp", "rust", "go", "python", "typescript"],
      "default_args": ["--workspace", "/workspace", "--lsp", "rust-analyzer"]
    },
    "mcp-nixos": {
      "enabled": true,
      "type": "python",
      "description": "NixOS package and configuration search MCP server",
      "repository": "https://github.com/utensils/mcp-nixos",
      "build_command": "pip install -e .",
      "binary_path": "python3 -m mcp_nixos.server",
      "install_path": "python3 -m mcp_nixos.server",
      "capabilities": ["nixos", "packages", "search", "configuration"],
      "default_args": [],
      "environment": {
        "ELASTICSEARCH_URL": "https://search.nixos.org/backend"
      }
    }
  }
}
```

### Adding New Servers

To add a new MCP server:

1. **Edit `config/servers.json`** - Add your server configuration
2. **Run `make rebuild`** - Rebuild and restart the container
3. **Update Claude Desktop config** - Add the new server to your MCP configuration

### Supported Server Types

- **go**: Go-based servers (uses `go install` or `go build`)
- **rust**: Rust-based servers (uses `cargo build --release`)
- **node**: Node.js servers (uses `npm install` and optional `npm run build`)
- **python**: Python servers (creates virtual environment and uses `pip install`)

## Docker Infrastructure

### Base Image
- **Ubuntu 25.04** with Python 3.13 support
- **Multi-language toolchain**: Go 1.24+, Rust (latest), Node.js 20, Python 3.13
- **rust-analyzer** pre-installed for Rust language support

### Volume Mounts
```yaml
volumes:
  - ./workspace:/workspace:rw     # Shared workspace
  - ./data:/app/data:rw          # Persistent data
  - ./logs:/var/log:rw           # Log files
  - ./config:/app/config:ro      # Configuration (read-only)
```

## Management Commands

```bash
# Container Operations
make build          # Build Docker image
make start          # Start container
make stop           # Stop container
make restart        # Restart container
make rebuild        # Clean rebuild (recommended after config changes)

# Monitoring
make logs           # View container logs
make health         # Run health check
make status         # Show MCP server status
make supervisor-logs # View supervisor logs
make server-logs    # View specific server logs (prompts for server name)

# Development
make shell          # Open container shell
make ssh-test       # Test SSH connectivity
make update-config  # Update configuration without rebuild
make info          # Show container information
```

## Technical Details

### Python Virtual Environments
Python servers automatically get isolated virtual environments:
- Created at `/app/servers/{server-name}/venv/`
- Dependencies installed via pip in the virtual environment
- Supervisor uses the venv Python binary: `/app/servers/{server-name}/venv/bin/python3`

### Process Management
- **Supervisor** manages all MCP servers as background processes
- Automatic restart on failure
- Structured logging to `/var/log/mcp/`
- Health monitoring and status reporting

### Networking
- Container runs without special network requirements
- Accessible via `docker exec` commands over SSH
- No exposed ports needed for MCP communication

## Troubleshooting

### Check Server Status
```bash
# View all servers
make status

# Check specific server logs
docker exec mcp-server-host tail -n 50 /var/log/mcp/mcp-language-server.err.log
docker exec mcp-server-host tail -n 50 /var/log/mcp/mcp-nixos.err.log
```

### Test Servers Individually
```bash
# Test language server
docker exec mcp-server-host /root/go/bin/mcp-language-server --help

# Test NixOS server
docker exec mcp-server-host /app/servers/mcp-nixos/venv/bin/python3 -m mcp_nixos.server --help
```

### Restart Failed Servers
```bash
# Restart specific server
docker exec mcp-server-host supervisorctl restart mcp-mcp-nixos
docker exec mcp-server-host supervisorctl restart mcp-mcp-language-server

# Restart all servers
docker exec mcp-server-host supervisorctl restart all
```

### SSH Access Issues
```bash
# Test SSH connection
ssh tim@tim-server "docker exec mcp-server-host echo 'SSH works'"

# Test specific MCP server via SSH
ssh tim@tim-server "docker exec mcp-server-host /root/go/bin/mcp-language-server --help"
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Logging level for MCP servers |
| `WORKSPACE_PATH` | `/workspace` | Working directory for projects |
| `MCP_SERVERS_CONFIG` | `/app/config/servers.json` | Server configuration file |

## Docker Compose Integration

The container runs without network dependencies:

```yaml
version: '3.8'
services:
  mcp-server-host:
    build: .
    image: mcp-server-host:latest
    container_name: mcp-server-host
    restart: unless-stopped
    volumes:
      - ./workspace:/workspace:rw
      - ./data:/app/data:rw
      - ./logs:/var/log:rw
      - ./config:/app/config:ro
    environment:
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - WORKSPACE_PATH=/workspace
    ports:
      - "8080:8080"  # Optional: for web-based servers
```