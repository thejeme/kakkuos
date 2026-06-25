#!/usr/bin/env bash
set -euo pipefail

REQUIRE_VM_TOOLS=0
REQUIRE_KVM=0
REQUIRE_UEFI=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Check whether this host is ready for KakkuOS ISO build and VM validation.
The check is read-only and does not prompt for sudo.

Options:
  --require-vm-tools   Fail when QEMU VM tools are missing.
  --require-kvm        Fail when /dev/kvm is not usable by this user.
  --require-uefi       Fail when OVMF UEFI firmware is missing.
  -h, --help           Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-vm-tools)
      REQUIRE_VM_TOOLS=1
      shift
      ;;
    --require-kvm)
      REQUIRE_KVM=1
      shift
      ;;
    --require-uefi)
      REQUIRE_UEFI=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

failures=0
warnings=0

ok() {
  printf 'ok   %s\n' "$*"
}

warn() {
  printf 'warn %s\n' "$*"
  warnings=$((warnings + 1))
}

miss() {
  printf 'miss %s\n' "$*"
  failures=1
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

check_required_command() {
  local command_name="$1"
  local package_hint="$2"

  if have_command "$command_name"; then
    ok "required command: $command_name"
  else
    miss "required command: $command_name ($package_hint)"
  fi
}

check_optional_command() {
  local command_name="$1"
  local package_hint="$2"

  if have_command "$command_name"; then
    ok "optional command: $command_name"
  elif (( REQUIRE_VM_TOOLS )); then
    miss "optional command required for VM tests: $command_name ($package_hint)"
  else
    warn "optional command missing for VM tests: $command_name ($package_hint)"
  fi
}

find_ovmf_code() {
  local candidate
  local candidates=(
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
    /usr/share/edk2-ovmf/OVMF_CODE.fd
    /usr/share/OVMF/OVMF_CODE.fd
    /usr/share/ovmf/x64/OVMF_CODE.fd
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

check_os_hint() {
  local os_release="/etc/os-release"
  local id_like=""
  local id=""

  if [[ -f "$os_release" ]]; then
    # shellcheck disable=SC1091
    . "$os_release"
    id="${ID:-}"
    id_like="${ID_LIKE:-}"
  fi

  case " $id $id_like " in
    *" cachyos "*|*" arch "*)
      ok "host looks Arch/CachyOS compatible: ${PRETTY_NAME:-unknown}"
      ;;
    *)
      warn "host is not clearly Arch/CachyOS based: ${PRETTY_NAME:-unknown}"
      ;;
  esac
}

check_pacman_repo_hint() {
  if [[ ! -f /etc/pacman.conf ]]; then
    warn "pacman.conf not found; cannot check CachyOS repo availability"
    return
  fi

  if grep -Eq '^\[(cachyos|cachyos-v3|cachyos-v4|cachyos-core-v3|cachyos-extra-v3)\]$' /etc/pacman.conf; then
    ok "CachyOS pacman repo stanza found"
  else
    warn "CachyOS pacman repo stanza not found; full builds need CachyOS repositories"
  fi
}

check_sudo() {
  if ! have_command sudo; then
    miss "sudo is installed"
    return
  fi

  ok "sudo is installed"
  if sudo -n true >/dev/null 2>&1; then
    ok "sudo can run non-interactively for this user"
  else
    warn "sudo non-interactive check failed; full build may prompt or fail"
  fi
}

check_loop_devices() {
  if [[ -e /dev/loop-control ]]; then
    ok "loop device control exists"
  else
    warn "/dev/loop-control missing; ISO build hosts need loop devices"
  fi
}

check_kvm() {
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ok "KVM is usable by this user"
  elif (( REQUIRE_KVM )); then
    miss "KVM is usable by this user"
  else
    warn "KVM is not usable by this user; VM tests can still run slower without acceleration"
  fi
}

check_uefi() {
  local ovmf_code

  ovmf_code="$(find_ovmf_code || true)"
  if [[ -n "$ovmf_code" ]]; then
    ok "OVMF UEFI firmware found: $ovmf_code"
  elif (( REQUIRE_UEFI )); then
    miss "OVMF UEFI firmware found"
  else
    warn "OVMF UEFI firmware missing; UEFI VM boot tests cannot run"
  fi
}

check_os_hint
check_pacman_repo_hint

check_required_command git git
check_required_command rsync rsync
check_required_command sed sed
check_required_command awk gawk
check_required_command makepkg base-devel
check_required_command repo-add pacman-contrib
check_required_command mkarchiso archiso
check_required_command mksquashfs squashfs-tools
check_required_command pacstrap arch-install-scripts
check_sudo
check_loop_devices

check_optional_command qemu-system-x86_64 qemu-desktop
check_optional_command qemu-img qemu-desktop
check_uefi
check_kvm

if (( failures )); then
  echo
  echo "ISO host preflight failed with $warnings warning(s)."
  exit 1
fi

echo
echo "ISO host preflight passed with $warnings warning(s)."
