#!/usr/bin/env bash
set -euo pipefail

# Lima + Podman Desktop Setup Wizard
#
# Interactive setup for Podman Desktop with a mutable Lima VM
# Can also be run non-interactively with command-line flags
#
# Remote installation:
#   bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh)
#
# What it does:
# - Checks and installs prerequisites (lima, podman) via brew
# - Creates/starts a Lima VM using template://podman (rootless or rootful)
# - Configures podman remote connection to unix://~/.lima/<vm>/sock/podman.sock
# - Optionally sets DOCKER_HOST for Docker CLI compatibility
# - Optionally installs VM-level packages via dnf inside the VM

usage() {
  cat <<'EOF'
Usage:
  setup-podman-lima.sh [options]

Without options, runs in interactive wizard mode.

Options:
  --quick                    Quick setup with recommended defaults (no prompts)
  --vm-name NAME             Lima VM name (default: podman)
  --cpus N                   CPUs (default: 4)
  --memory GB                Memory in GB (default: 8)
  --disk GB                  Disk in GB (default: 100)
  --mode rootless|rootful    Podman mode (default: rootless)
  --conn-name NAME           Podman connection name (default: lima-podman)
  --configure-podman-desktop Configure Podman Desktop settings (default: enabled)
  --skip-podman-desktop      Skip Podman Desktop configuration
  --persist-docker-host      Append DOCKER_HOST export to your shell profile
  --install-packages         Install default VM packages (vim jq iproute strace tcpdump)
  --packages "a b c"         Install custom packages (space-separated, implies --install-packages)
  -y, --yes                  Skip all confirmation prompts (use with flags)
  -h, --help                 Show this help

Examples:
  # Interactive wizard (recommended)
  ./setup-podman-lima.sh

  # Quick setup with defaults
  ./setup-podman-lima.sh --quick

  # Remote installation
  bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh)

  # Custom configuration (non-interactive)
  ./setup-podman-lima.sh --mode rootful --cpus 8 --memory 16 --persist-docker-host --install-packages -y
EOF
}

# Defaults
VM_NAME="podman"
CPUS=4
MEMORY_GB=8
DISK_GB=100
MODE="rootless"
CONN_NAME="lima-podman"
PERSIST_DOCKER_HOST=0
INSTALL_PACKAGES=0
PACKAGES_OVERRIDE=""
QUICK_MODE=0
AUTO_YES=0
INTERACTIVE_MODE=1
CONFIGURE_PODMAN_DESKTOP=1  # Default to yes

VM_PACKAGES_DEFAULT=("vim" "jq" "iproute" "strace" "tcpdump")

# Color output helpers
color() { local c="$1"; shift; printf "\033[%sm%s\033[0m" "$c" "$*"; }
info()  { echo "$(color 36 '==>') $*"; }
ok()    { echo "$(color 32 '✔') $*"; }
warn()  { echo "$(color 33 '⚠') $*"; }
err()   { echo "$(color 31 '✖') $*"; }
bold()  { echo "$(color '1' "$*")"; }

# Interactive prompt helpers
ask_yn() {
  local prompt="$1"
  local default="${2:-n}"

  if [[ "$AUTO_YES" -eq 1 ]]; then
    echo "y"
    return 0
  fi

  local yn
  if [[ "$default" == "y" ]]; then
    read -rp "$(color 33 '?') ${prompt} [Y/n]: " yn
    yn="${yn:-y}"
  else
    read -rp "$(color 33 '?') ${prompt} [y/N]: " yn
    yn="${yn:-n}"
  fi

  echo "$yn"
  [[ "$yn" =~ ^[Yy] ]]
}

ask_choice() {
  local prompt="$1"
  local default="$2"
  shift 2
  local options=("$@")

  echo "$(color 33 '?') ${prompt}"
  local i=1
  for opt in "${options[@]}"; do
    if [[ "$i" -eq "$default" ]]; then
      echo "  $(color 32 "${i})") ${opt} $(color 90 '(default)')"
    else
      echo "  ${i}) ${opt}"
    fi
    ((i++))
  done

  local choice
  read -rp "Enter choice [${default}]: " choice
  choice="${choice:-$default}"

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#options[@]}" ]]; then
    echo "$choice"
    return 0
  else
    err "Invalid choice"
    return 1
  fi
}

ask_input() {
  local prompt="$1"
  local default="$2"

  local input
  read -rp "$(color 33 '?') ${prompt} [${default}]: " input
  echo "${input:-$default}"
}

print_banner() {
  echo
  bold "╔════════════════════════════════════════════════════════╗"
  bold "║   Podman Desktop + Lima Setup Wizard                  ║"
  bold "║   Mutable VM with Full System Access                   ║"
  bold "╚════════════════════════════════════════════════════════╝"
  echo
}

check_prerequisites() {
  local missing=()

  if ! command -v brew &>/dev/null; then
    missing+=("homebrew")
  fi

  if ! command -v limactl &>/dev/null; then
    missing+=("lima")
  fi

  if ! command -v podman &>/dev/null; then
    missing+=("podman")
  fi

  if [[ "${#missing[@]}" -gt 0 ]]; then
    return 1
  fi

  return 0
}

install_prerequisites() {
  info "Checking prerequisites..."

  if ! command -v brew &>/dev/null; then
    err "Homebrew is not installed"
    echo "Install it from: https://brew.sh"
    echo "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
  fi

  local to_install=()

  if ! command -v limactl &>/dev/null; then
    to_install+=("lima")
  fi

  if ! command -v podman &>/dev/null; then
    to_install+=("podman")
  fi

  if [[ "${#to_install[@]}" -gt 0 ]]; then
    info "Installing missing tools: ${to_install[*]}"
    brew install "${to_install[@]}"
    ok "Prerequisites installed"
  else
    ok "All prerequisites present"
  fi
}

check_existing_vm() {
  if limactl list -q 2>/dev/null | grep -q "^${VM_NAME}\$"; then
    return 0
  fi
  return 1
}

handle_existing_vm() {
  warn "VM '${VM_NAME}' already exists"
  echo
  limactl list "${VM_NAME}" 2>/dev/null || true
  echo

  if ask_yn "Delete existing VM and recreate?" "n"; then
    info "Stopping and deleting VM '${VM_NAME}'..."
    limactl stop "${VM_NAME}" 2>/dev/null || true
    limactl delete "${VM_NAME}" 2>/dev/null || true
    ok "Existing VM removed"
    return 0
  else
    err "Cannot proceed with existing VM. Exiting."
    exit 1
  fi
}

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

configure_podman_desktop() {
  local vm_name="$1"
  local lima_type="$2"  # "podman" or "docker"

  # Determine settings file location based on OS
  local settings_file=""
  case "$(uname -s)" in
    Darwin|Linux)
      settings_file="${HOME}/.local/share/containers/podman-desktop/configuration/settings.json"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      settings_file="${USERPROFILE}/.local/share/containers/podman-desktop/configuration/settings.json"
      ;;
    *)
      warn "Unknown OS, skipping Podman Desktop configuration"
      return 0
      ;;
  esac

  # Check if Podman Desktop is installed
  if [[ ! -f "$settings_file" ]]; then
    info "Podman Desktop settings not found (app may not be installed)"
    echo "If you install Podman Desktop later, it will auto-detect this Lima VM"
    return 0
  fi

  info "Configuring Podman Desktop to use Lima VM..."

  # Backup existing settings
  cp "$settings_file" "${settings_file}.backup.$(date +%s)" 2>/dev/null || true

  # Determine socket name based on type
  local socket_name="${lima_type}"

  # Use jq if available, otherwise use basic sed
  if command -v jq &>/dev/null; then
    # Update settings using jq
    local temp_file="${settings_file}.tmp"
    jq --arg vm_name "$vm_name" \
       --arg lima_type "$lima_type" \
       --arg socket_name "$socket_name" \
       '.["lima.name"] = $vm_name |
        .["lima.type"] = $lima_type |
        .["lima.socket"] = $socket_name |
        .["lima.home"] = "~/.lima" |
        .["dockerCompatibility.enabled"] = true |
        .["podman.setting.dockerCompatibility"] = true' \
       "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"

    ok "Podman Desktop configured via jq"
  else
    # Fallback: manual JSON editing (basic approach)
    warn "jq not found, using basic configuration"

    # Check if settings already exist
    if grep -q '"lima.name"' "$settings_file"; then
      # Update existing
      sed -i.bak "s/\"lima.name\": *\"[^\"]*\"/\"lima.name\": \"${vm_name}\"/" "$settings_file"
      sed -i.bak "s/\"lima.type\": *\"[^\"]*\"/\"lima.type\": \"${lima_type}\"/" "$settings_file"
      sed -i.bak "s/\"lima.socket\": *\"[^\"]*\"/\"lima.socket\": \"${socket_name}\"/" "$settings_file"
    else
      # Add new settings before the last }
      sed -i.bak '$ d' "$settings_file"  # Remove last }
      cat >> "$settings_file" <<EOF
    "lima.name": "${vm_name}",
    "lima.type": "${lima_type}",
    "lima.socket": "${socket_name}",
    "lima.home": "~/.lima",
    "dockerCompatibility.enabled": true,
    "podman.setting.dockerCompatibility": true
}
EOF
    fi

    ok "Podman Desktop configured (basic method)"
  fi

  echo "Podman Desktop settings updated:"
  echo "  VM name:      ${vm_name}"
  echo "  Type:         ${lima_type}"
  echo "  Socket:       ${socket_name}.sock"
  echo
  warn "Restart Podman Desktop for changes to take effect"
}

run_interactive_wizard() {
  print_banner

  info "Welcome to the Podman Desktop + Lima setup wizard"
  echo "This will configure a mutable Fedora VM for Podman Desktop"
  echo

  # Setup mode selection
  local setup_choice
  setup_choice=$(ask_choice "Choose setup mode:" 1 \
    "Quick setup (recommended defaults: rootless, 4 CPU, 8GB RAM, 100GB disk)" \
    "Custom setup (configure all options)")

  if [[ "$setup_choice" -eq 1 ]]; then
    QUICK_MODE=1
    info "Using quick setup with recommended defaults"
    echo
  else
    echo

    # Podman mode
    local mode_choice
    mode_choice=$(ask_choice "Select Podman mode:" 1 \
      "Rootless (recommended, safer for development)" \
      "Rootful (needed for some Kubernetes tools)")

    if [[ "$mode_choice" -eq 2 ]]; then
      MODE="rootful"
    fi

    # VM resources
    echo
    CPUS=$(ask_input "CPU cores" "$CPUS")
    MEMORY_GB=$(ask_input "Memory (GB)" "$MEMORY_GB")
    DISK_GB=$(ask_input "Disk size (GB)" "$DISK_GB")

    # VM name
    echo
    VM_NAME=$(ask_input "VM name" "$VM_NAME")
  fi

  # Podman Desktop integration
  echo
  if ask_yn "Configure Podman Desktop to use this VM? (recommended if Podman Desktop is installed)" "y"; then
    CONFIGURE_PODMAN_DESKTOP=1
  else
    CONFIGURE_PODMAN_DESKTOP=0
  fi

  # Docker compatibility
  echo
  if ask_yn "Enable Docker CLI compatibility? (sets DOCKER_HOST in shell profile)" "y"; then
    PERSIST_DOCKER_HOST=1
  fi

  # VM packages
  echo
  if ask_yn "Install development packages in VM? (vim, jq, tcpdump, strace, etc.)" "y"; then
    INSTALL_PACKAGES=1
  fi

  # Summary
  echo
  bold "Configuration Summary:"
  echo "  VM Name:           ${VM_NAME}"
  echo "  Mode:              ${MODE}"
  echo "  CPU:               ${CPUS} cores"
  echo "  Memory:            ${MEMORY_GB} GB"
  echo "  Disk:              ${DISK_GB} GB"
  echo "  Podman Desktop:    $(if [[ "$CONFIGURE_PODMAN_DESKTOP" -eq 1 ]]; then echo "Configure"; else echo "Skip"; fi)"
  echo "  Docker CLI Compat: $(if [[ "$PERSIST_DOCKER_HOST" -eq 1 ]]; then echo "Enabled"; else echo "Disabled"; fi)"
  echo "  VM Packages:       $(if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then echo "Yes"; else echo "No"; fi)"
  echo

  if ! ask_yn "Proceed with installation?" "y"; then
    echo "Setup cancelled"
    exit 0
  fi
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; INTERACTIVE_MODE=0; shift 2 ;;
    --cpus) CPUS="$2"; INTERACTIVE_MODE=0; shift 2 ;;
    --memory) MEMORY_GB="$2"; INTERACTIVE_MODE=0; shift 2 ;;
    --disk) DISK_GB="$2"; INTERACTIVE_MODE=0; shift 2 ;;
    --mode) MODE="$2"; INTERACTIVE_MODE=0; shift 2 ;;
    --conn-name) CONN_NAME="$2"; shift 2 ;;
    --quick) QUICK_MODE=1; INTERACTIVE_MODE=0; shift ;;
    --configure-podman-desktop) CONFIGURE_PODMAN_DESKTOP=1; INTERACTIVE_MODE=0; shift ;;
    --skip-podman-desktop) CONFIGURE_PODMAN_DESKTOP=0; INTERACTIVE_MODE=0; shift ;;
    --persist-docker-host) PERSIST_DOCKER_HOST=1; INTERACTIVE_MODE=0; shift ;;
    --install-packages) INSTALL_PACKAGES=1; INTERACTIVE_MODE=0; shift ;;
    --packages) PACKAGES_OVERRIDE="$2"; INSTALL_PACKAGES=1; INTERACTIVE_MODE=0; shift 2 ;;
    -y|--yes) AUTO_YES=1; shift ;;
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
  # Run interactive wizard if no flags provided
  if [[ "$INTERACTIVE_MODE" -eq 1 ]]; then
    run_interactive_wizard
    echo
  fi

  # Install prerequisites
  install_prerequisites
  echo

  # Check for existing VM
  if check_existing_vm; then
    handle_existing_vm
    echo
  fi

  # Start VM creation
  info "Creating Lima VM '${VM_NAME}' with ${TEMPLATE}..."
  echo "  CPU:    ${CPUS} cores"
  echo "  Memory: ${MEMORY_GB} GB"
  echo "  Disk:   ${DISK_GB} GB"
  echo
  info "This may take a few minutes on first run (downloading Fedora image)..."

  if limactl start \
    --name="${VM_NAME}" \
    --cpus="${CPUS}" \
    --memory="${MEMORY_GB}" \
    --disk="${DISK_GB}" \
    "${TEMPLATE}" 2>&1 | grep -v "^INFO" || true; then
    ok "VM '${VM_NAME}' is running"
  else
    err "Failed to start VM"
    exit 1
  fi
  echo

  # Verify socket
  info "Verifying Podman socket..."
  local retries=10
  while [[ $retries -gt 0 ]]; do
    if [[ -S "${SOCK_PATH}" ]]; then
      ok "Podman socket ready"
      break
    fi
    ((retries--))
    sleep 1
  done

  if [[ ! -S "${SOCK_PATH}" ]]; then
    err "Podman socket not found at ${SOCK_PATH}"
    echo "Try debugging with: limactl shell ${VM_NAME}"
    exit 1
  fi
  echo

  # Configure Podman connection
  info "Configuring Podman CLI connection..."
  podman system connection add "${CONN_NAME}" "${SOCK_URI}" 2>/dev/null || true
  podman system connection default "${CONN_NAME}"
  ok "Podman connection configured: ${CONN_NAME}"
  echo

  # Test connection
  info "Testing Podman connection..."
  if podman info >/dev/null 2>&1; then
    ok "Podman CLI connected successfully"
  else
    err "Failed to connect to Podman"
    exit 1
  fi
  echo

  # Install VM packages
  if [[ "$INSTALL_PACKAGES" -eq 1 ]]; then
    local pkgs=()
    if [[ -n "$PACKAGES_OVERRIDE" ]]; then
      # shellcheck disable=SC2206
      pkgs=($PACKAGES_OVERRIDE)
    else
      pkgs=("${VM_PACKAGES_DEFAULT[@]}")
    fi

    info "Installing development packages in VM: ${pkgs[*]}"
    if limactl shell "${VM_NAME}" -- sudo dnf install -y "${pkgs[@]}" 2>&1 | tail -n 5; then
      ok "VM packages installed"
    else
      warn "Some packages may have failed to install"
    fi
    echo
  fi

  # Configure Podman Desktop
  if [[ "$CONFIGURE_PODMAN_DESKTOP" -eq 1 ]]; then
    configure_podman_desktop "${VM_NAME}" "podman"
    echo
  fi

  # Configure Docker compatibility
  if [[ "$PERSIST_DOCKER_HOST" -eq 1 ]]; then
    info "Configuring Docker CLI compatibility..."
    append_export_to_profile "${SOCK_URI}"
    echo
  fi

  # Success message
  echo
  bold "╔════════════════════════════════════════════════════════╗"
  bold "║   Setup Complete!                                      ║"
  bold "╚════════════════════════════════════════════════════════╝"
  echo

  if [[ "$CONFIGURE_PODMAN_DESKTOP" -eq 1 ]]; then
    ok "Podman Desktop configured - restart the app to use the new VM"
  else
    ok "Lima VM ready - Podman Desktop should auto-detect it"
  fi
  echo
  echo "Quick reference:"
  echo "  Podman socket: ${SOCK_URI}"
  echo "  Enter VM:      limactl shell ${VM_NAME}"
  echo "  Stop VM:       limactl stop ${VM_NAME}"
  echo "  Start VM:      limactl start ${VM_NAME}"
  echo

  if [[ "$PERSIST_DOCKER_HOST" -eq 1 ]]; then
    echo "Docker CLI compatibility enabled!"
    echo "  Open a new terminal or run: source ~/.zshrc (or ~/.bashrc)"
    echo "  Test with: docker ps"
    echo
  else
    echo "To enable Docker CLI compatibility, run:"
    echo "  export DOCKER_HOST=\"${SOCK_URI}\""
    echo "  Then test with: docker ps"
    echo
  fi
}

main