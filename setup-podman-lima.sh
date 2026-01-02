#!/usr/bin/env bash
set -euo pipefail

# Lima + Podman Template Setup Wizard
# - Creates/starts a Lima VM using template://podman or template://podman-rootful
# - Configures podman remote connection to the VM's podman.sock
# - Optionally installs VM-level packages via dnf
# - Prints (and optionally appends) DOCKER_HOST export for docker/docker-compose compatibility

VM_NAME_DEFAULT="podman"
CPUS_DEFAULT=4
MEMORY_GB_DEFAULT=8
DISK_GB_DEFAULT=100
CONN_NAME_DEFAULT="lima-podman"

# Default VM-level packages (optional)
VM_PACKAGES_DEFAULT=("vim" "jq" "iproute" "strace" "tcpdump")

color() { local c="$1"; shift; printf "\033[%sm%s\033[0m" "$c" "$*"; }
info()  { echo "$(color 36 '==>') $*"; }
ok()    { echo "$(color 32 '✔') $*"; }
warn()  { echo "$(color 33 '⚠') $*"; }
err()   { echo "$(color 31 '✖') $*"; }

prompt() {
  local msg="$1" default="${2:-}"
  if [[ -n "$default" ]]; then
    read -r -p "$msg [$default]: " ans
    echo "${ans:-$default}"
  else
    read -r -p "$msg: " ans
    echo "$ans"
  fi
}

prompt_yn() {
  local msg="$1" default="${2:-y}" ans
  local hint
  if [[ "$default" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
  read -r -p "$msg ($hint): " ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

choose_runtime() {
  echo
  echo "Choose Podman runtime mode:"
  echo "  1) Rootless (recommended)"
  echo "  2) Rootful (needed for some privileged/k8s use cases)"
  local choice
  while true; do
    choice="$(prompt 'Enter choice' '1')"
    case "$choice" in
      1) echo "template://podman"; return 0 ;;
      2) echo "template://podman-rootful"; return 0 ;;
      *) warn "Please enter 1 or 2." ;;
    esac
  done
}

append_export_to_profile() {
  local export_line="$1"
  local shell_name="${SHELL##*/}"
  local profile=""

  case "$shell_name" in
    zsh)  profile="${HOME}/.zshrc" ;;
    bash) profile="${HOME}/.bashrc" ;;
    fish) profile="${HOME}/.config/fish/config.fish" ;;
    *)    profile="${HOME}/.profile" ;;
  esac

  if [[ "$shell_name" == "fish" ]]; then
    # fish syntax differs; we’ll just print instructions instead of writing.
    warn "Detected fish shell. Not auto-writing DOCKER_HOST to fish config."
    echo "Add this to ${profile}:"
    echo "  set -x DOCKER_HOST \"$export_line\""
    return 0
  fi

  if grep -Fqs "$export_line" "$profile" 2>/dev/null; then
    ok "DOCKER_HOST export already present in ${profile}"
    return 0
  fi

  echo "" >> "$profile"
  echo "# Added by Lima+Podman setup wizard" >> "$profile"
  echo "export DOCKER_HOST=\"$export_line\"" >> "$profile"
  ok "Appended DOCKER_HOST export to ${profile}"
  echo "Open a new shell or run: source \"$profile\""
}

main() {
  echo
  echo "Lima + Podman Template Setup Wizard"
  echo "----------------------------------"

  local VM_NAME CPUS MEMORY_GB DISK_GB CONN_NAME TEMPLATE
  VM_NAME="$(prompt 'VM name' "$VM_NAME_DEFAULT")"
  CPUS="$(prompt 'CPUs' "$CPUS_DEFAULT")"
  MEMORY_GB="$(prompt 'Memory (GB)' "$MEMORY_GB_DEFAULT")"
  DISK_GB="$(prompt 'Disk (GB)' "$DISK_GB_DEFAULT")"
  CONN_NAME="$(prompt 'Podman connection name' "$CONN_NAME_DEFAULT")"
  TEMPLATE="$(choose_runtime)"

  echo
  info "Installing prerequisites (lima, podman)..."
  brew install lima podman >/dev/null
  ok "Prerequisites installed"

  echo
  info "Starting Lima VM '${VM_NAME}' with ${TEMPLATE} (${CPUS} CPU, ${MEMORY_GB}GB RAM, ${DISK_GB}GB disk)..."
  limactl start \
    --name="${VM_NAME}" \
    --cpus="${CPUS}" \
    --memory="${MEMORY_GB}" \
    --disk="${DISK_GB}" \
    "${TEMPLATE}" >/dev/null
  ok "VM is running"

  local SOCK_PATH SOCK_URI
  SOCK_PATH="${HOME}/.lima/${VM_NAME}/sock/podman.sock"
  SOCK_URI="unix://${SOCK_PATH}"

  echo
  info "Verifying Podman socket exists: ${SOCK_PATH}"
  if [[ ! -S "${SOCK_PATH}" ]]; then
    err "Podman socket not found at ${SOCK_PATH}"
    echo
    echo "Try entering the VM to inspect status:"
    echo "  limactl shell ${VM_NAME}"
    exit 1
  fi
  ok "Podman socket found"

  echo
  info "Configuring podman remote connection '${CONN_NAME}'..."
  podman system connection add "${CONN_NAME}" "${SOCK_URI}" 2>/dev/null || true
  podman system connection default "${CONN_NAME}"
  ok "Podman connection set to default: ${CONN_NAME}"

  echo
  info "Testing podman connection..."
  podman info >/dev/null
  ok "podman is connected to Lima VM"

  echo
  echo "Docker/Docker Compose compatibility:"
  echo "  export DOCKER_HOST=\"${SOCK_URI}\""
  echo

  # "Auto run export" only affects this script process; we can at least do it for immediate follow-on commands.
  if prompt_yn "Set DOCKER_HOST for this terminal session now?" "y"; then
    export DOCKER_HOST="${SOCK_URI}"
    ok "DOCKER_HOST exported for current session"
  fi

  if prompt_yn "Persist DOCKER_HOST export in your shell profile?" "n"; then
    append_export_to_profile "${SOCK_URI}"
  fi

  if prompt_yn "Install VM-level packages via dnf inside the VM now?" "n"; then
    echo
    echo "Default packages: ${VM_PACKAGES_DEFAULT[*]}"
    local custom
    custom="$(prompt 'Enter packages (space-separated) or press Enter to use defaults' '')"
    local pkgs=()
    if [[ -n "$custom" ]]; then
      # shellcheck disable=SC2206
      pkgs=($custom)
    else
      pkgs=("${VM_PACKAGES_DEFAULT[@]}")
    fi

    info "Installing packages in VM (sudo dnf install -y ...)"
    # limactl ssh no longer exists; limactl shell with a command executes remotely
    limactl shell "${VM_NAME}" -- sudo dnf install -y "${pkgs[@]}"
    ok "Installed: ${pkgs[*]}"
  fi

  echo
  ok "Setup complete."
  echo
  echo "Useful commands:"
  echo "  podman system connection list"
  echo "  podman info"
  echo "  podman ps"
  echo
  echo "Enter the VM (mutable Fedora Cloud):"
  echo "  limactl shell ${VM_NAME}"
  echo
  echo "Install VM-level packages later:"
  echo "  limactl shell ${VM_NAME} -- sudo dnf install -y <packages...>"
  echo
  echo "If DOCKER_HOST is set, docker tooling will target Podman:"
  echo "  docker ps"
  echo "  docker compose build"
  echo
}

main "$@"