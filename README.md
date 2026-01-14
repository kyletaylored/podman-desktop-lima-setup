# Podman Desktop with Lima (Mutable VM)

## Overview

Podman Desktop’s default setup provisions a **Fedora CoreOS** virtual machine, which is **immutable/read-only by design**. This prevents installing VM-level packages (`dnf`, system tools, debuggers, etc.) and makes system customization difficult.

This guide uses **Lima (`limactl`) with the official Podman template**, which provisions a **mutable Fedora Cloud VM** that:

* Is **natively supported by Podman Desktop**
* Runs **Podman as the container engine**
* Exposes a **host-accessible Podman socket**
* Allows **VM-level package installation**
* Supports **docker / docker-compose** via a compatible API

This is the **cleanest and officially supported** way to use Podman Desktop with a writable VM.

---

## Architecture

```
macOS
 ├── Podman Desktop (GUI)
 ├── podman CLI (remote)
 ├── docker / docker-compose (optional)
 └── Lima VM (Fedora Cloud, mutable)
      └── Podman engine
```

---

## Prerequisites

```bash
brew install lima podman
```

(Optional, if you use Docker tooling)

```bash
brew install docker docker-compose
```

---

## Quick Start (Recommended)

Run the **interactive setup wizard**:

```bash
./setup-podman-lima.sh
```

The wizard will:

* Ask whether you want **rootless** or **rootful** Podman
* Create a Lima VM (4 CPU / 8 GB RAM / 100 GB disk)
* Configure the **Podman system connection**
* Optionally export and persist `DOCKER_HOST`
* Optionally install VM-level packages
* Leave you with a ready-to-use Podman Desktop engine

---

## Manual Setup (Step-by-Step)

### 1. Create the Lima Podman VM

#### Rootless Podman (recommended)

```bash
limactl start \
  --name=podman \
  --cpus=4 \
  --memory=8 \
  --disk=100 \
  template://podman
```

#### Rootful Podman (only if required)

```bash
limactl start \
  --name=podman \
  --cpus=4 \
  --memory=8 \
  --disk=100 \
  template://podman-rootful
```

This downloads a **Fedora Cloud** image (mutable, systemd-enabled).

---

### 2. Configure the Podman CLI (host → VM)

The Podman template prints the exact commands needed. For reference:

```bash
podman system connection add lima-podman \
  "unix://${HOME}/.lima/podman/sock/podman.sock"

podman system connection default lima-podman
```

Verify:

```bash
podman info
podman run quay.io/podman/hello
```

Podman Desktop will automatically detect this engine.

---

### 3. Configure Docker / docker-compose (optional)

Podman exposes a **Docker-compatible API** via the same socket.

```bash
export DOCKER_HOST="unix://${HOME}/.lima/podman/sock/podman.sock"
```

Test:

```bash
docker ps
docker compose version
docker compose build
```

Persist this in your shell profile if desired.

---

## Entering the VM (SSH / shell)

To enter the VM:

```bash
limactl shell podman
```

This opens an interactive shell inside the VM.

**Inside the VM:**

* User: `lima`
* OS: Fedora Cloud
* Package manager: `dnf`
* systemd: enabled
* Filesystem: writable & persistent

---

## Installing VM-Level Packages

Example:

```bash
sudo dnf install -y \
  vim \
  tcpdump \
  strace \
  iproute \
  jq
```

Packages persist across reboots.

You can also run commands non-interactively:

```bash
limactl shell podman -- sudo dnf install -y htop
```

---

## VM Lifecycle Management

```bash
limactl stop podman
limactl start podman
limactl delete podman
```

---

## Filesystem Layout (Reference)

```text
~/.lima/podman/
├── lima.yaml
├── basedisk
├── diffdisk
└── sock/
    └── podman.sock   ← used by podman and docker
```

---

## Rootless vs Rootful Podman

| Mode                                  | When to use                                             |
| ------------------------------------- | ------------------------------------------------------- |
| Rootless (`template://podman`)        | Default, safest, best for dev                           |
| Rootful (`template://podman-rootful`) | Needed for some Kubernetes tools, privileged containers |

Both run on the same mutable Fedora Cloud VM.

---

## Why This Approach

| Requirement                   | Result         |
| ----------------------------- | -------------- |
| Mutable VM                    | ✅ Fedora Cloud |
| Podman Desktop native support | ✅              |
| podman CLI on host            | ✅              |
| docker / docker-compose       | ✅              |
| VM-level package installs     | ✅              |
| No CoreOS immutability        | ✅              |

This setup avoids:

* Fedora CoreOS limitations
* Podman Machine quirks
* Colima/Docker compatibility hacks

---

## TL;DR

```bash
limactl start template://podman
podman system connection add lima-podman unix://~/.lima/podman/sock/podman.sock
export DOCKER_HOST=unix://~/.lima/podman/sock/podman.sock
limactl shell podman
```