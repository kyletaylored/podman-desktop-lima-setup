#!/usr/bin/env bash
set -euo pipefail

# Lima + Podman Template Setup (defaults-first) + simple CLI options
#
# What it does:
# - Installs prerequisites (lima, podman) via brew
# - Creates/starts a Lima VM using template://podman (rootless) by default
# - Configures podman remote connection to unix://~/.lima/<vm>/sock/podman.sock
# - Optionally sets DOCKER_HOST for this session and/or persists it to shell profile
# - Optionally installs VM-level packages via dnf inside the VM
#
# Note: `limactl shell <vm>` is used for interactive SSH; and `limactl shell <vm> -- <cmd>` for remote commands.

usage() {
  cat <<'EOF'
Usage:
  setup-podman-lima.sh [options]

Options (defaults shown):
  --vm-name NAME             Lima VM name (default: podman)
  --cpus N                   CPUs (default: 4)
  --memory GB                Memory in GB (default: 8)
  --disk GB                  Disk in GB (default: 100)
  --mode rootless|rootful    Podman mode (default: rootless)
  --conn-name NAME           Podman connection name (default: lima-podman)

  --set-docker-host          Export DOCKER_HOST for the current shell *via output*
                             (prints an export line you can eval)
  --persist-docker-host      Append DOCKER_HOST export to your shell profile
                             (~/.zshrc, ~/.bashrc, ~/.profile; fish not auto-written)

  --install-packages         Install default VM packages (see below)
  --packages "a b c"         Override package list (space-separated)
                             (implies --install-packages)

  --no-brew                  Skip brew install step (assumes tools already installed)
  -h, --help                 Show this help

Default VM packages (when --install-packages):
  vim jq iproute strace tcpdump

Examples:
  # Default setup (rootless, 4c/8g/100g), configure podman connection
  ./setup-podman-lima.sh

  # Rootful VM, persist DOCKER_HOST, install packages
  ./setup-podman-lima.sh --mode rootful --persist-docker-host --install-packages

  # Print export you can eval in current shell
  eval "$(./setup-podman-lima.sh --set-docker-host)"

  # Custom VM name + custom packages
  ./setup-podman-lima.sh --vm-name podman-dev --packages "vim htop git"
EOF
}

# Defaults
VM_NAME="podman"
CPUS=4
MEMORY_GB=8
DISK_GB=100
MODE="rootless"
CONN_NAME="lima-podman"
NO_BREW=0
SET_DOCKER_HOST=0
PERSIST_DOCKER_HOST=0
INSTALL_PACKAGES=0
PACKAGES_OVERRIDE=""

VM_PACKAGES_DEFAULT=("vim" "jq" "iproute" "strace" "tcpdump")

color() { local c="$1"; shift; printf "\033[%sm%s\033[0m" "$c" "$*"; }
info()  { echo "$(color 36 '==>') $*"; }
ok()    { echo "$(color 32 '✔') $*"; }
warn()  { echo "$(color 33 '⚠') $*"; }
err()   { echo "$(color 31 '✖') $*"; }

append_export_to_profile() {
  local docker_host_uri="$1"
  local shell_name="${SHELL##*/}"
  local profile=""

  case "$shell_name" in
    zsh)  profile="${HOME}/.zshrc" ;;
    bash) profile="${HOME}/.bashrc" ;;
    fish) profile="${HOME}/.config/fish/config.fish" ;;
    *)    profile="${HOME}/.profile" ;;
  esac

  if [[ "$shell_name" == "fish" ]]; then
    warn "fish shell detected; not auto-writing export syntax."
    echo "Add this to ${profile}:"
    echo "  set -x DOCKER_HOST \"${docker_host_uri}\""
    return 0
  fi

  if grep -Fqs "export DOCKER_HOST=\"${docker_host_uri}\"" "$profile" 2>/dev/null; then
    ok "DOCKER_HOST already present in ${profile}"
    return 0
  fi

  {
    echo ""
    echo "# Added by Lima+Podman setup"
    echo "export DOCKER_HOST=\"${docker_host_uri}\""
  } >> "$profile"

  ok "Appended DOCKER_HOST export to ${profile}"
  echo "Open a new shell or run: source \"$profile\""
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --memory) MEMORY_GB="$2"; shift 2 ;;
    --disk) DISK_GB="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --conn-name) CONN_NAME="$2"; shift 2 ;;
    --no-brew) NO_BREW=1; shift ;;
    --set-docker-host) SET_DOCKER_HOST=1; shift ;;
    --persist-docker-host) PERSIST_DOCKER_HOST=1; shift ;;
    --install-packages) INSTALL_PACKAGES=1; shift ;;
    --packages) PACKAGES_OVERRIDE="$2"; INSTALL_PACKAGES=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; echo; usage; exit 2 ;;
  esac
done

# Validate mode
if [[ "$MODE" != "rootless" && "$MODE" != "rootful" ]]; then
  err "--mode must be 'rootless' or 'rootful' (got: $MODE)"
  exit 2
fi

TEMPLATE="template://podman"
[[ "$MODE" == "rootful" ]] && TEMPLATE="template://podman-rootful"

SOCK_PATH="${HOME}/.lima/${VM_NAME}/sock/podman.sock"
SOCK_URI="unix://${SOCK_PATH}"

main() {
  if [[ "$NO_BREW" -eq 0 ]]; then
    info "Installing prerequisites (lima, podman)..."
    brew install lima podman >/dev/null
    ok "Prerequisites installed"
  else
    info "Skipping brew install (--no-brew)"
  fi

  info "Starting Lima VM '${VM_NAME}' with ${TEMPLATE} (${CPUS} CPU, ${MEMORY_GB}GB RAM, ${DISK_GB}GB disk)..."
  limactl start \
    --name="${VM_NAME}" \
    --cpus="${CPUS}" \
    --memory="${MEMORY_GB}" \
    --disk="${DISK_GB}" \
    "${TEMPLATE}" >/dev/null
  ok "VM is running"

  info "Verifying Podman socket exists: ${SOCK_PATH}"
  if [[ ! -S "${SOCK_PATH}" ]]; then
    err "Podman socket not found at ${SOCK_PATH}"
    echo "Try: limactl shell ${VM_NAME}"
    exit 1
  fi
  ok "Podman socket found"

  info "Configuring podman connection '${CONN_NAME}'..."
  podman system connection add "${CONN_NAME}" "${SOCK_URI}" 2>/dev/null || true
  podman system connection default "${CONN_NAME}"
  ok "Podman connection set to default: ${CONN_NAME}"

  info "Testing podman connection..."
  podman info >/dev/null
  ok "podman is connected"

  if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then
    local pkgs=()
    if [[ -n "$PACKAGES_OVERRIDE" ]]; then
      # shellcheck disable=SC2206
      pkgs=($PACKAGES_OVERRIDE)
    else
      pkgs=("${VM_PACKAGES_DEFAULT[@]}")
    fi

    info "Installing VM packages via dnf: ${pkgs[*]}"
    limactl shell "${VM_NAME}" -- sudo dnf install -y "${pkgs[@]}"
    ok "VM packages installed"
  fi

  if [[ "$PERSIST_DOCKER_HOST" -eq 1 ]]; then
    append_export_to_profile "${SOCK_URI}"
  fi

  # If requested, print an export line the user can eval in their shell:
  #   eval "$(./setup-podman-lima.sh --set-docker-host)"
  if [[ "$SET_DOCKER_HOST" -eq 1 ]]; then
    echo "export DOCKER_HOST=\"${SOCK_URI}\""
  fi

  echo
  ok "Done."
  echo "Podman socket: ${SOCK_URI}"
  echo "Enter VM: limactl shell ${VM_NAME}"
  echo "Docker compat: export DOCKER_HOST=\"${SOCK_URI}\""
}

main