# Podman Desktop + Lima Setup

> **One-command setup for Podman Desktop with a fully mutable Fedora VM**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Why This Setup?

Podman Desktop's default VM uses **Fedora CoreOS**, which is **immutable by design**. This prevents installing packages, debugging tools, or customizing the system environment.

This setup uses **Lima with the official Podman template** to provision a **mutable Fedora Cloud VM** that gives you:

✅ **Full system access** - Install any packages with `dnf`
✅ **Podman Desktop native support** - Auto-detected, no hacks
✅ **Docker CLI compatibility** - Works with `docker` and `docker-compose`
✅ **Persistent customization** - System changes survive reboots
✅ **Development tools** - `vim`, `tcpdump`, `strace`, debuggers, etc.

---

## Quick Installation

### One-Line Install (Recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh)
```

The interactive wizard will guide you through:
- Choosing rootless (recommended) or rootful Podman
- Configuring VM resources (CPU, memory, disk)
- Enabling Docker CLI compatibility
- Installing development tools in the VM

### Quick Setup (No Prompts)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh) --quick
```

Uses sensible defaults: rootless mode, 4 CPU, 8GB RAM, 100GB disk.

---

## What You Get

### Architecture

```
macOS Host
 ├── Podman Desktop (GUI) ──────┐
 ├── podman CLI (remote) ───────┼──> Lima VM (Fedora Cloud, mutable)
 └── docker CLI (optional) ─────┘     └── Podman engine (rootless/rootful)
```

### System Details

- **VM OS**: Fedora Cloud (mutable, systemd-enabled)
- **Container Engine**: Podman (rootless by default)
- **Socket**: `unix://~/.lima/podman/sock/podman.sock`
- **Package Manager**: `dnf` (full access)
- **Default Resources**: 4 CPU / 8GB RAM / 100GB disk

## Prerequisites

The setup script will check and install these automatically via Homebrew:

- **Homebrew** (required) - [Install here](https://brew.sh)
- **Lima** (`limactl`) - Installed via script
- **Podman** CLI - Installed via script

### Optional Tools

```bash
# For Docker CLI compatibility
brew install docker docker-compose
```

---

## Usage

### Interactive Wizard Mode

```bash
./setup-podman-lima.sh
```

Walks you through all configuration options with helpful prompts.

### Quick Mode (Defaults)

```bash
./setup-podman-lima.sh --quick
```

### Custom Configuration

```bash
./setup-podman-lima.sh \
  --mode rootful \
  --cpus 8 \
  --memory 16 \
  --disk 200 \
  --persist-docker-host \
  --install-packages
```

### Available Options

| Option | Description | Default |
|--------|-------------|---------|
| `--quick` | Quick setup with defaults | - |
| `--vm-name NAME` | Lima VM name | `podman` |
| `--cpus N` | CPU cores | `4` |
| `--memory GB` | Memory in GB | `8` |
| `--disk GB` | Disk size in GB | `100` |
| `--mode MODE` | `rootless` or `rootful` | `rootless` |
| `--persist-docker-host` | Add DOCKER_HOST to shell profile | disabled |
| `--install-packages` | Install dev tools in VM | disabled |
| `--packages "a b c"` | Custom package list | vim jq iproute strace tcpdump |
| `-y, --yes` | Skip confirmations | - |
| `-h, --help` | Show help | - |

---

## Working with the VM

### Enter the VM

```bash
limactl shell podman
```

Opens an interactive shell inside the Fedora VM.

### VM Environment

Once inside:
- **User**: `lima`
- **OS**: Fedora Cloud
- **Package manager**: `dnf`
- **Systemd**: enabled
- **Filesystem**: writable & persistent

### Install Packages

```bash
# Inside the VM
sudo dnf install -y vim htop tcpdump strace
```

Or from the host:

```bash
limactl shell podman -- sudo dnf install -y vim htop
```

Packages persist across reboots.

### VM Lifecycle

```bash
limactl stop podman      # Stop the VM
limactl start podman     # Start the VM
limactl list             # List all VMs
limactl delete podman    # Delete the VM
```

---

## Docker CLI Compatibility

Podman exposes a Docker-compatible API socket that `docker` and `docker-compose` can use.

### Enable Docker Compatibility

The script can automatically add this to your shell profile with `--persist-docker-host`, or set it manually:

```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

### Test Docker CLI

```bash
docker ps
docker run hello-world
docker compose version
```

### Persist in Shell Profile

Add to `~/.zshrc`, `~/.bashrc`, or `~/.profile`:

```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

---

## Podman Desktop Integration

The setup script **automatically configures** Podman Desktop to use your Lima VM!

### What Gets Configured

The script updates Podman Desktop settings:
- Lima VM name and type
- Socket location
- Docker compatibility mode

### How to Use

1. **Run the setup script** (it configures Podman Desktop by default)
2. **Restart Podman Desktop** app
3. The Lima VM appears in the dashboard
4. Use the GUI to manage containers, images, volumes, etc.

### Skip Podman Desktop Configuration

If you don't use Podman Desktop or want to configure it manually:

```bash
./setup-podman-lima.sh --skip-podman-desktop
```

Podman Desktop may still auto-detect the VM through the Lima extension.

### Manual Configuration

See [PODMAN_DESKTOP_INTEGRATION.md](docs/PODMAN_DESKTOP_INTEGRATION.md) for details on:
- How CLI and GUI connections work together
- Manual Podman Desktop configuration
- Troubleshooting connection issues
- Settings file format and location

---

## Rootless vs Rootful Mode

| Mode | Use Case | Security | Compatibility |
|------|----------|----------|---------------|
| **Rootless** | Development, most use cases | Higher (non-root) | Good |
| **Rootful** | Kubernetes tools, privileged containers | Lower (root access) | Better |

Choose **rootless** unless you specifically need rootful capabilities.

---

## Troubleshooting

### VM won't start

```bash
# Check Lima VM status
limactl list

# View VM logs
limactl shell podman -- journalctl -xe
```

### Podman socket not found

```bash
# Verify socket exists
ls -la ~/.lima/podman/sock/podman.sock

# Restart VM
limactl stop podman && limactl start podman
```

### Podman Desktop not detecting VM

```bash
# Check connection
podman system connection list

# Set default connection
podman system connection default lima-podman

# Restart Podman Desktop
```

### Clean reinstall

```bash
# Delete VM completely
limactl delete podman

# Run setup again
./setup-podman-lima.sh
```

---

## Advanced Configuration

### Custom VM Resources

```bash
./setup-podman-lima.sh --cpus 8 --memory 16 --disk 200
```

### Multiple VMs

```bash
# Create additional VMs with different names
./setup-podman-lima.sh --vm-name podman-dev --mode rootless
./setup-podman-lima.sh --vm-name podman-k8s --mode rootful
```

### VM Configuration File

After creation, edit VM settings:

```bash
limactl edit podman
```

Restart VM for changes to take effect:

```bash
limactl stop podman && limactl start podman
```

---

## Why This Approach?

### Comparison with Alternatives

| Feature | Lima + Podman | Podman Machine | Docker Desktop | Colima |
|---------|---------------|----------------|----------------|--------|
| Mutable VM | ✅ | ❌ (CoreOS) | ❌ (Alpine) | ✅ |
| Native Podman Desktop | ✅ | ✅ | ❌ | ❌ |
| Docker CLI compat | ✅ | ✅ | ✅ | ✅ |
| Free for commercial | ✅ | ✅ | ❌ | ✅ |
| Package installation | ✅ | ❌ | ❌ | ✅ |
| Official Podman | ✅ | ✅ | ❌ | ❌ |

### Benefits

✅ Uses **official Lima Podman templates** (maintained by Lima team)
✅ **Zero configuration hacks** or workarounds
✅ **Full Fedora Cloud** with complete package access
✅ **Seamless Podman Desktop** integration
✅ **Docker CLI compatibility** without Docker Desktop licensing
✅ **Persistent customization** survives reboots

---

## Manual Setup (Without Script)

If you prefer manual setup:

```bash
# Install prerequisites
brew install lima podman

# Start Lima VM with Podman template
limactl start --name=podman --cpus=4 --memory=8 --disk=100 template://podman

# Configure Podman connection
podman system connection add lima-podman "unix://${HOME}/.lima/podman/sock/podman.sock"
podman system connection default lima-podman

# Test connection
podman info

# Optional: Docker compatibility
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

---

## Contributing

Contributions welcome! Please open an issue or pull request.

---

## License

MIT License - See [LICENSE](LICENSE) file for details

---

## Resources

- [Lima Project](https://lima-vm.io/)
- [Podman Desktop](https://podman-desktop.io/)
- [Podman Documentation](https://docs.podman.io/)
- [Lima Podman Template](https://github.com/lima-vm/lima/blob/master/examples/podman.yaml)