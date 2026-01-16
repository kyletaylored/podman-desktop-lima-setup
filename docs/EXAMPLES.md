# Usage Examples

Practical examples for different use cases.

## Quick Start Examples

### 1. Interactive Setup (Recommended for First Time)

```bash
# Download and run the wizard
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh)
```

Follow the prompts to configure your VM.

### 2. Quick Setup with Defaults

```bash
# One command, zero questions
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh) --quick
```

Creates VM with:
- Rootless Podman
- 4 CPU cores
- 8 GB RAM
- 100 GB disk

## Common Scenarios

### Developer Workstation

```bash
./setup-podman-lima.sh \
  --mode rootless \
  --cpus 4 \
  --memory 8 \
  --persist-docker-host \
  --install-packages
```

Best for:
- Local development
- Docker Compose projects
- Learning containers

### High-Performance Development

```bash
./setup-podman-lima.sh \
  --mode rootless \
  --cpus 8 \
  --memory 16 \
  --disk 200 \
  --persist-docker-host \
  --install-packages
```

Best for:
- Large codebases
- Multiple concurrent services
- Build-heavy workflows

### Kubernetes Development

```bash
./setup-podman-lima.sh \
  --mode rootful \
  --cpus 6 \
  --memory 12 \
  --disk 150 \
  --install-packages \
  --packages "vim jq kubectl helm"
```

Best for:
- Testing Kubernetes workloads
- Kind/K3s clusters
- Privileged containers

### CI/CD Testing

```bash
./setup-podman-lima.sh \
  --quick \
  --vm-name podman-ci \
  -y
```

Best for:
- Automated testing
- CI pipelines
- Temporary environments

### Minimal Setup

```bash
./setup-podman-lima.sh \
  --mode rootless \
  --cpus 2 \
  --memory 4 \
  --disk 50 \
  -y
```

Best for:
- Low-resource machines
- Basic container testing
- Learning/experimentation

## Multiple VM Configurations

### Development + Testing VMs

```bash
# Development VM (rootless)
./setup-podman-lima.sh \
  --vm-name podman-dev \
  --mode rootless \
  --cpus 4 \
  --memory 8 \
  --persist-docker-host \
  --install-packages

# Testing VM (rootful)
./setup-podman-lima.sh \
  --vm-name podman-test \
  --mode rootful \
  --cpus 4 \
  --memory 8 \
  --install-packages
```

Switch between VMs:

```bash
# Use dev VM
podman system connection default lima-podman-dev

# Use test VM
podman system connection default lima-podman-test
```

## Advanced Customization

### Custom Package Installation

```bash
./setup-podman-lima.sh \
  --quick \
  --packages "vim git htop ncdu ripgrep fd-find bat tmux"
```

### Install Debugging Tools

```bash
./setup-podman-lima.sh \
  --quick \
  --packages "gdb strace ltrace tcpdump wireshark-cli sysstat perf"
```

### Install Network Tools

```bash
./setup-podman-lima.sh \
  --quick \
  --packages "nmap netcat socat iperf3 mtr bind-utils"
```

## Docker Compose Workflows

### Setup for Docker Compose Projects

```bash
# 1. Setup VM with Docker compatibility
./setup-podman-lima.sh --quick --persist-docker-host

# 2. Install docker-compose on host (if not installed)
brew install docker-compose

# 3. Source your shell config
source ~/.zshrc  # or ~/.bashrc

# 4. Test docker commands
docker ps
docker compose version

# 5. Run your docker-compose project
cd your-project
docker compose up -d
```

## Post-Installation Tasks

### Enter the VM

```bash
limactl shell podman
```

### Install Additional Software in VM

```bash
# From host
limactl shell podman -- sudo dnf install -y nodejs npm python3 pip

# Or enter VM and install
limactl shell podman
sudo dnf install -y nodejs npm python3 pip
```

### Configure Port Forwarding

Lima automatically forwards ports, but you can customize in the VM config:

```bash
limactl edit podman
```

Add port mappings:

```yaml
portForwards:
- guestPort: 8080
  hostPort: 8080
- guestPort: 3000
  hostPort: 3000
```

Restart VM:

```bash
limactl stop podman && limactl start podman
```

### Copy Files to VM

```bash
# From host to VM
limactl copy myfile.txt podman:/home/lima/

# From VM to host
limactl copy podman:/home/lima/result.txt ./
```

## Troubleshooting Examples

### Clean Reinstall

```bash
# 1. Delete VM
limactl delete podman

# 2. Run setup again
./setup-podman-lima.sh --quick
```

### Fix Docker Connection

```bash
# 1. Verify socket exists
ls -la ~/.lima/podman/sock/podman.sock

# 2. Set DOCKER_HOST
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"

# 3. Test
docker ps
```

### Reset Podman Connection

```bash
# 1. Remove old connections
podman system connection rm lima-podman

# 2. Re-add connection
podman system connection add lima-podman "unix://${HOME}/.lima/podman/sock/podman.sock"
podman system connection default lima-podman

# 3. Test
podman info
```

### Check VM Status

```bash
# List all VMs
limactl list

# Show VM details
limactl info podman

# Check VM logs
limactl shell podman -- sudo journalctl -xe

# Check Podman service
limactl shell podman -- systemctl --user status podman.socket
```

## Performance Tuning

### Allocate More Resources

Edit VM after creation:

```bash
limactl edit podman
```

Change:

```yaml
cpus: 8
memory: 16GiB
disk: 200GiB
```

Restart:

```bash
limactl stop podman
limactl start podman
```

### Enable VM Caching

```bash
# Inside VM
limactl shell podman

# Enable filesystem cache
sudo sysctl -w vm.vfs_cache_pressure=50
sudo sysctl -w vm.dirty_ratio=15
```

## Integration Examples

### VS Code with Podman

1. Install VS Code extensions:
   - Docker (works with Podman)
   - Remote - Containers

2. Configure VS Code settings (`.vscode/settings.json`):

```json
{
  "docker.host": "unix:///Users/YOUR-USERNAME/.lima/podman/sock/podman.sock"
}
```

### JetBrains IDEs (IntelliJ, PyCharm, etc.)

1. Go to **Preferences** → **Build, Execution, Deployment** → **Docker**
2. Click **+** to add new connection
3. Select **Docker for Mac**
4. Set socket: `/Users/YOUR-USERNAME/.lima/podman/sock/podman.sock`

### Portainer

```bash
# Run Portainer
podman run -d \
  --name portainer \
  -p 9443:9443 \
  -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock:ro \
  portainer/portainer-ce:latest

# Access at https://localhost:9443
```

## Cleaning Up

### Remove VM

```bash
limactl delete podman
```

### Remove All Lima VMs

```bash
limactl delete --all
```

### Uninstall Everything

```bash
# Remove Lima VMs
limactl delete --all

# Remove Podman connections
podman system connection rm --all

# Remove Docker host from shell profile
# Edit ~/.zshrc or ~/.bashrc and remove DOCKER_HOST line

# Uninstall packages (optional)
brew uninstall lima podman
```
