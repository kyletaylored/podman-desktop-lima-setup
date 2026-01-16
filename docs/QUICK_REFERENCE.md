# Quick Reference Card

## Installation

```bash
# Interactive wizard
bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh)

# Quick setup (defaults)
bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh) --quick

# Show help
bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh) -h
```

## VM Management

```bash
limactl list                  # List all VMs
limactl start podman         # Start VM
limactl stop podman          # Stop VM
limactl delete podman        # Delete VM
limactl shell podman         # Enter VM
limactl info podman          # Show VM info
```

## Podman Commands

```bash
podman ps                    # List running containers
podman images                # List images
podman run IMAGE             # Run container
podman pull IMAGE            # Pull image
podman info                  # Show system info
podman system connection list  # List connections
```

## Docker Compatibility

```bash
# Enable Docker CLI
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"

# Test
docker ps
docker compose up
```

## Package Installation (in VM)

```bash
# Enter VM
limactl shell podman

# Install packages
sudo dnf install -y vim git htop

# Or from host
limactl shell podman -- sudo dnf install -y vim
```

## Troubleshooting

```bash
# Check socket
ls -la ~/.lima/podman/sock/podman.sock

# Reset connection
podman system connection rm lima-podman
podman system connection add lima-podman "unix://${HOME}/.lima/podman/sock/podman.sock"
podman system connection default lima-podman

# View VM logs
limactl shell podman -- journalctl -xe

# Clean reinstall
limactl delete podman
./setup-podman-lima.sh --quick
```

## File Locations

```
~/.lima/podman/               # VM directory
├── sock/podman.sock         # Podman socket
├── lima.yaml                # VM configuration
└── diffdisk                 # VM disk

~/.config/containers/        # Podman config
~/.zshrc or ~/.bashrc        # Shell profile (DOCKER_HOST)
```

## Common Options

```bash
--quick                      # Use defaults, no prompts
--vm-name NAME              # Custom VM name
--cpus N                    # CPU cores (default: 4)
--memory GB                 # Memory GB (default: 8)
--disk GB                   # Disk GB (default: 100)
--mode rootless|rootful     # Podman mode
--persist-docker-host       # Add DOCKER_HOST to shell
--install-packages          # Install dev tools
--packages "a b c"          # Custom packages
-y, --yes                   # Skip confirmations
```

## Resources

- Default: 4 CPU / 8 GB RAM / 100 GB disk
- Mode: rootless (safer) or rootful (more compatible)
- OS: Fedora Cloud (mutable)

## Help

```bash
./setup-podman-lima.sh --help
```

See [README.md](README.md) for full documentation.
