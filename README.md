# MCP Server Host

A modular Docker container for hosting multiple MCP (Model Context Protocol) servers with remote SSH access support. Perfect for running MCP servers on a NixOS server or any Docker-compatible system.

## Features

- **Multi-Language Support**: Go, Rust, Node.js, Python
- **Modular Architecture**: Easy to add/remove servers via JSON configuration
- **Process Management**: Supervisor handles all MCP servers
- **Remote Access**: SSH + docker exec integration
- **Health Monitoring**: Built-in health checks and logging
- **NixOS Ready**: Designed for integration with NixOS configurations

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
├── Dockerfile                    # Multi-stage build for all languages
├── docker-compose.yml           # Container orchestration
├── Makefile                     # Management commands
├── entrypoint.sh               # Container startup script
├── supervisord.conf            # Process management
├── config/
│   └── servers.json           # Server configuration
├── scripts/
│   ├── install-servers.sh     # Server installation
│   ├── start-servers.sh       # Supervisor config generation
│   └── health-check.sh        # Health monitoring
└── README.md                  # This file
```

## Configuration

### Adding a New MCP Server

Edit `config/servers.json`:

```json
{
  "servers": {
    "your-server": {
      "enabled": true,
      "type": "rust",
      "description": "Your custom MCP server",
      "repository": "https://github.com/you/your-mcp-server",
      "build_command": "cargo build --release",
      "binary_path": "./target/release/your-server",
      "capabilities": ["feature1", "feature2"]
    }
  }
}
```

Then rebuild:

```bash
make rebuild
```

### Server Types

- **go**: Go-based servers (uses `go build`)
- **rust**: Rust-based servers (uses `cargo build`)
- **node**: Node.js servers (uses `npm install/build`)
- **python**: Python servers (uses `pip install`)

## NixOS Integration

Add to your NixOS configuration:

```nix
virtualisation.oci-containers.containers = {
  mcp-server-host = {
    image = "mcp-server-host:latest";
    autoStart = true;
    autoRemoveOnStop = false;
    extraOptions = ["--network=docker-network" "--ip=172.18.0.15"];
    volumes = [
      "/mnt/docker-data/volumes/mcp-workspace:/workspace:rw"
      "/mnt/docker-data/volumes/mcp-data:/app/data:rw"
      "/mnt/docker-data/volumes/mcp-logs:/var/log:rw"
      "/var/run/docker.sock:/var/run/docker.sock:rw"
    ];
    environment = {
      LOG_LEVEL = "info";
      WORKSPACE_PATH = "/workspace";
    };
  };
};
```

## Claude Desktop Configuration

Configure Claude Desktop to use remote MCP servers:

```json
{
  "mcpServers": {
    "language-server-rust": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "/root/go/bin/mcp-language-server",
        "--workspace", "/workspace/rust-project",
        "--lsp", "rust-analyzer"
      ]
    },
    "rust-docs": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "/app/servers/rust-docs/target/release/rust-docs-mcp-server",
        "--crate", "tokio"
      ]
    },
    "tailwind-svelte": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "node", "/app/servers/tailwind-svelte/dist/index.js"
      ]
    }
  }
}
```

## Pre-configured Servers

### 1. Language Server (Go)
- LSP integration for multiple languages
- Supports: Rust, Go, Python, TypeScript
- Repository: [mcp-language-server](https://github.com/garrettguan/mcp-language-server)

### 2. Rust Docs (Rust)
- Documentation server with semantic search
- No OpenAI key required
- Repository: [mcp-rust-docs](https://github.com/shaman-apprentice/mcp-rust-docs)

### 3. Tailwind Svelte Assistant (Node.js)
- SvelteKit + Tailwind component generation
- Repository: [tailwind-svelte-mcp](https://github.com/keturiosakys/tailwind-svelte-mcp)

### 4. Code Runner (Node.js)
- Multi-language code execution
- Supports: Python, JavaScript, Bash

### 5. NixOS MCP (Node.js)
- NixOS system management
- Configuration generation and deployment

## Management Commands

```bash
# Basic Operations
make build          # Build Docker image
make start          # Start container
make stop           # Stop container
make restart        # Restart container
make rebuild        # Clean rebuild

# Monitoring
make logs           # View container logs
make health         # Health check
make status         # Show server status
make supervisor-logs # View supervisor logs
make server-logs    # View specific server logs

# Development
make shell          # Open container shell
make ssh-test       # Test SSH connectivity
make update-config  # Update configuration
make info          # Show container info

# Deployment
make deploy         # Production deployment
make clean         # Remove everything
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `WORKSPACE_PATH` | `/workspace` | Working directory for MCP servers |
| `MCP_SERVERS_CONFIG` | `/app/config/servers.json` | Server configuration file |

## Volumes

| Container Path | Purpose |
|----------------|---------|
| `/workspace` | Shared workspace for all servers |
| `/app/data` | Persistent data storage |
| `/var/log` | Log files |
| `/app/config` | Server configuration (read-only) |

## SSH Access

### Setup SSH Key Authentication

On your local machine:

```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "mcp-server-access"

# Copy to NixOS server
ssh-copy-id tim@tim-server
```

### Test Connection

```bash
# Test SSH to container
make ssh-test

# Manual test
ssh tim@tim-server "docker exec mcp-server-host echo 'Connected!'"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs

# Verify configuration
docker exec mcp-server-host cat /app/config/servers.json

# Check supervisor status
docker exec mcp-server-host supervisorctl status
```

### Server Not Working

```bash
# Check specific server logs
docker exec mcp-server-host tail -n 100 /var/log/mcp/[server-name].err.log

# Restart specific server
docker exec mcp-server-host supervisorctl restart mcp-[server-name]
```

### SSH Connection Issues

```bash
# Test basic SSH
ssh tim@tim-server echo "SSH works"

# Test Docker access
ssh tim@tim-server docker ps

# Check container name
ssh tim@tim-server docker ps --filter name=mcp-server-host
```

## Adding Custom Servers

### Example: Adding a Python MCP Server

1. Edit `config/servers.json`:

```json
{
  "servers": {
    "python-analyzer": {
      "enabled": true,
      "type": "python",
      "description": "Python code analyzer",
      "repository": "https://github.com/example/python-mcp",
      "build_command": "pip install -r requirements.txt",
      "binary_path": "python main.py",
      "capabilities": ["analyze", "lint", "format"]
    }
  }
}
```

2. Rebuild container:

```bash
make rebuild
```

3. Configure Claude Desktop:

```json
{
  "mcpServers": {
    "python-analyzer": {
      "command": "ssh",
      "args": [
        "tim@tim-server",
        "docker", "exec", "mcp-server-host",
        "python3", "/app/servers/python-analyzer/main.py"
      ]
    }
  }
}
```

## Security Considerations

- Container runs with limited privileges
- SSH access requires key authentication
- Logs are rotated to prevent disk fill
- Health checks monitor resource usage
- Network isolation via Docker networks

## Performance Tuning

### Memory Limits

Add to `docker-compose.yml`:

```yaml
services:
  mcp-server-host:
    mem_limit: 4g
    memswap_limit: 4g
```

### CPU Limits

```yaml
services:
  mcp-server-host:
    cpus: '2.0'
```

## Contributing

1. Fork the repository
2. Add your server to `config/servers.json`
3. Test with `make rebuild`
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review container logs: `make logs`
- Open an issue on GitHub

## Acknowledgments

Built for seamless integration with:
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [Claude Desktop](https://claude.ai/desktop)
- [NixOS](https://nixos.org/)