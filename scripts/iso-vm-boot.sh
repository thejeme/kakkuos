#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ISO_PATH=""
ISO_OUT_DIR="${KAKKU_ISO_OUT_DIR:-$REPO_ROOT/iso/out}"
DISK_PATH="${KAKKU_VM_DISK:-$REPO_ROOT/iso/.cache/kakku-vm.qcow2}"
MEMORY="${KAKKU_VM_MEMORY:-4096}"
CPUS="${KAKKU_VM_CPUS:-2}"
DISK_SIZE="${KAKKU_VM_DISK_SIZE:-32G}"
FIRMWARE="bios"
EXTRA_QEMU_ARGS=()

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS] [-- QEMU_ARGS...]

Boot a KakkuOS ISO in QEMU for live or install validation.

Options:
  --iso PATH       ISO path. Default: newest *.iso under iso/out.
  --out DIR        ISO output directory for auto-discovery. Default: iso/out.
  --disk PATH      VM disk path. Default: iso/.cache/kakku-vm.qcow2.
  --disk-size SIZE Disk size when creating a missing disk. Default: 32G.
  --memory MB      VM memory. Default: 4096.
  --cpus N         VM CPU count. Default: 2.
  --bios           Boot with default BIOS firmware. Default.
  --uefi           Boot with OVMF UEFI firmware when available.
  --no-disk        Boot live ISO without attaching a persistent disk.
  -h, --help       Show this help.

Environment:
  KAKKU_ISO_OUT_DIR
  KAKKU_VM_DISK
  KAKKU_VM_MEMORY
  KAKKU_VM_CPUS
  KAKKU_VM_DISK_SIZE
EOF
}

use_disk=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)
      ISO_PATH="$2"
      shift 2
      ;;
    --out)
      ISO_OUT_DIR="$2"
      shift 2
      ;;
    --disk)
      DISK_PATH="$2"
      shift 2
      ;;
    --disk-size)
      DISK_SIZE="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --cpus)
      CPUS="$2"
      shift 2
      ;;
    --bios)
      FIRMWARE="bios"
      shift
      ;;
    --uefi)
      FIRMWARE="uefi"
      shift
      ;;
    --no-disk)
      use_disk=0
      shift
      ;;
    --)
      shift
      EXTRA_QEMU_ARGS=("$@")
      break
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

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

find_latest_iso() {
  if [[ ! -d "$ISO_OUT_DIR" ]]; then
    return 1
  fi

  find "$ISO_OUT_DIR" -type f -name '*.iso' -printf '%T@ %p\n' |
    sort -nr |
    awk 'NR == 1 { sub(/^[^ ]+ /, ""); print }'
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

require_command qemu-system-x86_64

if [[ -z "$ISO_PATH" ]]; then
  ISO_PATH="$(find_latest_iso || true)"
fi

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "No ISO found. Build one first with: iso/build-kakku-iso.sh" >&2
  echo "Looked under: $ISO_OUT_DIR" >&2
  exit 1
fi

qemu_args=(
  -m "$MEMORY"
  -smp "$CPUS"
  -cdrom "$ISO_PATH"
  -boot d
)

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  qemu_args+=(-enable-kvm -cpu host)
fi

if (( use_disk )); then
  require_command qemu-img
  if [[ ! -f "$DISK_PATH" ]]; then
    mkdir -p "$(dirname "$DISK_PATH")"
    qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
  fi
  qemu_args+=(-drive "file=$DISK_PATH,format=qcow2,if=virtio")
fi

if [[ "$FIRMWARE" == "uefi" ]]; then
  ovmf_code="$(find_ovmf_code || true)"
  if [[ -z "$ovmf_code" ]]; then
    echo "Could not find OVMF firmware. Install edk2-ovmf or use --bios." >&2
    exit 1
  fi
  qemu_args+=(-drive "if=pflash,format=raw,readonly=on,file=$ovmf_code")
fi

exec qemu-system-x86_64 "${qemu_args[@]}" "${EXTRA_QEMU_ARGS[@]}"
