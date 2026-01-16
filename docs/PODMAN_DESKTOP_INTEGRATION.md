# Podman Desktop Integration Guide

## Overview

This document explains how the setup script integrates with Podman Desktop and how the different connection methods work together.

## Two Connection Systems

### 1. CLI Connection (`podman system connection`)

**What it is:**
- Configuration for the `podman` command-line tool
- Stored in `~/.config/containers/containers.conf` and connection files
- Used when you run `podman ps`, `podman run`, etc. in the terminal

**How we configure it:**
```bash
podman system connection add lima-podman "unix://${HOME}/.lima/podman/sock/podman.sock"
podman system connection default lima-podman
```

**Purpose:**
- Makes the `podman` CLI work from your terminal
- Connects to the Lima VM's Podman socket

### 2. Podman Desktop GUI Connection

**What it is:**
- Configuration for the Podman Desktop application (GUI)
- Stored in `~/.local/share/containers/podman-desktop/configuration/settings.json`
- Used by the Podman Desktop graphical interface

**How we configure it:**
```json
{
  "lima.type": "podman",
  "lima.name": "podman",
  "lima.socket": "podman",
  "lima.home": "~/.lima",
  "dockerCompatibility.enabled": true,
  "podman.setting.dockerCompatibility": true
}
```

**Purpose:**
- Tells Podman Desktop which Lima VM to use
- Enables the Lima extension in Podman Desktop
- Configures Docker compatibility features

## How They Work Together

```
┌───────────────────────────────────────────────────────────────┐
│                         Your Mac                               │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  Terminal (CLI)                 Podman Desktop (GUI)          │
│  ├─ podman ps ────────┐         ├─ Containers view ──┐        │
│  ├─ docker ps ────────┤         ├─ Images view ───────┤        │
│  └─ docker compose ───┤         └─ Volumes view ──────┤        │
│                        │                               │        │
│                        ↓                               ↓        │
│              ~/.lima/podman/sock/podman.sock                   │
│                        ↑                                        │
└────────────────────────┼────────────────────────────────────────┘
                         │
                         ↓
┌───────────────────────────────────────────────────────────────┐
│                  Lima VM (Fedora Cloud)                        │
│                                                                │
│               Podman Engine (rootless/rootful)                │
│               ├─ Container runtime                            │
│               ├─ Image storage                                │
│               └─ Socket: /run/podman/podman.sock             │
└───────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Both systems connect to the **SAME socket**
- The socket is exposed from the Lima VM to your Mac
- CLI and GUI can be used simultaneously
- They see the same containers, images, and volumes

## Connection Methods Explained

### `podman system connection`

This is for the CLI only:

```bash
# List connections
podman system connection list

# Example output:
# Name         URI                                            Default
# lima-podman  unix:///Users/you/.lima/podman/sock/podman.sock  true
```

**Commands that use this:**
- `podman ps`
- `podman images`
- `podman run`
- All `podman` CLI commands

### Podman Desktop Settings

This is for the GUI only:

**Location:**
- macOS/Linux: `~/.local/share/containers/podman-desktop/configuration/settings.json`
- Windows: `%USERPROFILE%\.local\share\containers\podman-desktop\configuration\settings.json`

**Key settings:**
```json
{
  "lima.type": "podman",          // Type of engine (podman or docker)
  "lima.name": "podman",          // Lima VM name
  "lima.socket": "podman",        // Socket name (without .sock)
  "lima.home": "~/.lima",         // Lima home directory
  "dockerCompatibility.enabled": true  // Enable Docker socket compat
}
```

### Docker CLI Compatibility

For `docker` and `docker-compose` commands:

```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

**Commands that use this:**
- `docker ps`
- `docker run`
- `docker compose up`
- All `docker` CLI commands

**How it works:**
- Podman exposes a Docker-compatible API
- The `docker` CLI connects to Podman's socket instead of Docker's
- Most Docker commands work transparently

## What the Script Does

### 1. Creates Lima VM
```bash
limactl start --name=podman template://podman
```

### 2. Configures CLI Connection
```bash
podman system connection add lima-podman "unix://~/.lima/podman/sock/podman.sock"
podman system connection default lima-podman
```

### 3. Configures Podman Desktop
Updates `settings.json` with:
- VM name and type
- Socket location
- Docker compatibility flags

### 4. (Optional) Configures Docker CLI
Adds to shell profile:
```bash
export DOCKER_HOST="unix://~/.lima/podman/sock/podman.sock"
```

## Your Settings Analysis

Your current `settings.json` has:
```json
{
  "lima.type": "docker",      // ⚠️ Type is docker
  "lima.name": "podman",      // But name is podman
  "lima.socket": "podman"     // And socket is podman
}
```

**Issue:** Inconsistent configuration!

**Should be:**
```json
{
  "lima.type": "podman",      // ✅ Type matches socket
  "lima.name": "podman",      // ✅ Name is podman
  "lima.socket": "podman"     // ✅ Socket is podman
}
```

## Why Both Systems?

**Question:** Why not just use Podman Desktop settings?

**Answer:** They serve different purposes:

1. **CLI Connection** (`podman system connection`)
   - Used by: Terminal, scripts, CI/CD
   - Config location: User's containers config
   - Advantage: Works without Podman Desktop installed

2. **Podman Desktop Settings**
   - Used by: Podman Desktop GUI
   - Config location: Podman Desktop's config
   - Advantage: GUI-specific features and extensions

**They're independent!** You can:
- Use CLI without Podman Desktop
- Use Podman Desktop without CLI
- Use both together (recommended)

## Testing Your Setup

### Test CLI Connection

```bash
# Test podman CLI
podman info
podman ps

# Test docker CLI (if DOCKER_HOST is set)
docker info
docker ps
```

### Test Podman Desktop

1. Open Podman Desktop app
2. Check if Lima VM shows up in the dashboard
3. Try viewing containers/images
4. If not working, restart Podman Desktop

### Verify Settings

```bash
# Check CLI connection
podman system connection list

# Check Podman Desktop settings (macOS/Linux)
cat ~/.local/share/containers/podman-desktop/configuration/settings.json | grep lima

# Check socket exists
ls -la ~/.lima/podman/sock/podman.sock
```

## Common Issues

### Podman Desktop doesn't see the VM

**Cause:** Settings not configured or Lima extension disabled

**Fix:**
```bash
# Run script with Podman Desktop configuration
./setup-podman-lima.sh --configure-podman-desktop

# Or manually edit settings.json
# Then restart Podman Desktop
```

### CLI works but Podman Desktop doesn't

**Cause:** Two different configurations

**Fix:**
- Check Podman Desktop settings match your VM name
- Restart Podman Desktop after changes
- Verify Lima extension is enabled in Podman Desktop

### Docker commands don't work

**Cause:** DOCKER_HOST not set

**Fix:**
```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"

# Or persist it
echo 'export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"' >> ~/.zshrc
source ~/.zshrc
```

### Settings inconsistency (docker vs podman)

**Cause:** Mixed configuration types

**Fix:** Make them consistent:
```json
// If using Podman VM:
{
  "lima.type": "podman",
  "lima.name": "podman",
  "lima.socket": "podman"
}

// If using Docker VM:
{
  "lima.type": "docker",
  "lima.name": "docker",
  "lima.socket": "docker"
}
```

## Script Configuration

### Interactive Mode

The wizard asks:
```
? Configure Podman Desktop to use this VM? [Y/n]
```

**Select Y:**
- Script updates Podman Desktop settings
- Automatic configuration
- Restart Podman Desktop to apply

**Select N:**
- Skips Podman Desktop configuration
- You can configure manually later
- Podman Desktop may auto-detect the VM

### Command-Line Flags

```bash
# Explicitly configure Podman Desktop
./setup-podman-lima.sh --configure-podman-desktop

# Skip Podman Desktop configuration
./setup-podman-lima.sh --skip-podman-desktop

# Quick setup (includes Podman Desktop by default)
./setup-podman-lima.sh --quick
```

## Best Practices

1. **Use consistent naming:**
   - If VM is named "podman", use type "podman"
   - If VM is named "docker", use type "docker"

2. **Configure both systems:**
   - Set up CLI connection for terminal use
   - Set up Podman Desktop for GUI use

3. **Enable Docker compatibility:**
   - Good for Docker Compose projects
   - Easier migration from Docker Desktop

4. **Restart Podman Desktop:**
   - Always restart after changing settings
   - Settings only apply on app restart

## Manual Configuration

### Configure CLI Only

```bash
podman system connection add my-lima "unix://${HOME}/.lima/podman/sock/podman.sock"
podman system connection default my-lima
```

### Configure Podman Desktop Only

Edit `~/.local/share/containers/podman-desktop/configuration/settings.json`:

```json
{
  "lima.name": "podman",
  "lima.type": "podman",
  "lima.socket": "podman",
  "lima.home": "~/.lima"
}
```

Then restart Podman Desktop.

### Configure Docker CLI

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

## Summary

- **Two independent systems:** CLI and GUI
- **Both connect to same socket:** No conflicts
- **Script configures both:** Automatic setup
- **Can be used separately:** Choose what you need
- **Docker compatibility:** Works with docker commands
- **Consistency matters:** Keep names and types aligned

The script makes all of this automatic, but understanding the underlying connections helps troubleshoot issues!
