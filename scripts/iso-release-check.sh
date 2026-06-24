#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHYOS_LIVE_ISO_DIR="${CACHYOS_LIVE_ISO_DIR:-$REPO_ROOT/iso/.cache/cachyos-live-iso}"
KAKKU_STAGING_DIR="${KAKKU_STAGING_DIR:-$REPO_ROOT/iso/.cache/kakku-live-iso}"
KAKKU_ISO_OUT_DIR="${KAKKU_ISO_OUT_DIR:-$REPO_ROOT/iso/out}"
KAKKU_ISO_MANIFEST_NAME="${KAKKU_ISO_MANIFEST_NAME:-kakku-iso-build-manifest.txt}"
ALLOW_MISSING_ISO=0
ALLOW_MISSING_VM_TOOLS=0
ALLOW_DIRTY_SOURCE=0
REQUIRE_HOSTED_REPO=0
CHECK_HOST_PREFLIGHT=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Audit release-readiness after staging or building the KakkuOS ISO.

Options:
  --out DIR              ISO artifact directory. Default: iso/out.
  --staging-dir DIR      Staged KakkuOS/CachyOS-Live-ISO tree.
                         Default: iso/.cache/kakku-live-iso.
  --upstream-dir DIR     Cached upstream CachyOS-Live-ISO checkout.
                         Default: iso/.cache/cachyos-live-iso.
  --allow-missing-iso    Do not fail when no ISO artifact has been built yet.
  --allow-missing-vm-tools
                         Warn instead of failing when QEMU is missing.
  --allow-dirty-source   Warn instead of failing when manifest records a dirty
                         KakkuOS worktree.
  --require-hosted-repo  Fail unless the manifest records kakku_repo_mode=hosted.
  --check-host           Run the build/VM host preflight as part of the audit.
  -h, --help             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      KAKKU_ISO_OUT_DIR="$2"
      shift 2
      ;;
    --staging-dir)
      KAKKU_STAGING_DIR="$2"
      shift 2
      ;;
    --upstream-dir)
      CACHYOS_LIVE_ISO_DIR="$2"
      shift 2
      ;;
    --allow-missing-iso)
      ALLOW_MISSING_ISO=1
      shift
      ;;
    --allow-missing-vm-tools)
      ALLOW_MISSING_VM_TOOLS=1
      shift
      ;;
    --allow-dirty-source)
      ALLOW_DIRTY_SOURCE=1
      shift
      ;;
    --require-hosted-repo)
      REQUIRE_HOSTED_REPO=1
      shift
      ;;
    --check-host)
      CHECK_HOST_PREFLIGHT=1
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

check_command() {
  local command_name="$1"
  local label="$2"

  if have_command "$command_name"; then
    ok "$label"
  else
    miss "$label: missing command $command_name"
  fi
}

check_upstream_cache_clean() {
  if [[ ! -d "$CACHYOS_LIVE_ISO_DIR/.git" ]]; then
    miss "upstream CachyOS cache exists as git checkout"
    return
  fi

  if [[ -n "$(git -C "$CACHYOS_LIVE_ISO_DIR" status --short)" ]]; then
    miss "upstream CachyOS cache is clean"
  else
    ok "upstream CachyOS cache is clean"
  fi
}

check_staging_smoke() {
  if "$REPO_ROOT/scripts/iso-smoke-check.sh" --dir "$KAKKU_STAGING_DIR"; then
    ok "staged ISO smoke check"
  else
    miss "staged ISO smoke check"
  fi
}

check_target_hook() {
  if "$REPO_ROOT/scripts/iso-target-hook-check.sh" --staging-dir "$KAKKU_STAGING_DIR"; then
    ok "target install hook dry-run"
  else
    miss "target install hook dry-run"
  fi
}

check_iso_artifacts() {
  local iso
  local iso_count=0
  local checksum_file
  local sig_file

  if [[ ! -d "$KAKKU_ISO_OUT_DIR" ]]; then
    if (( ALLOW_MISSING_ISO )); then
      warn "ISO output directory missing: $KAKKU_ISO_OUT_DIR"
    else
      miss "ISO output directory exists: $KAKKU_ISO_OUT_DIR"
    fi
    return
  fi

  while IFS= read -r -d '' iso; do
    iso_count=$((iso_count + 1))
    ok "ISO artifact: $iso"

    checksum_file="$iso.sha256"
    if [[ -f "$checksum_file" ]]; then
      if (cd "$(dirname "$iso")" && sha256sum -c "$(basename "$checksum_file")"); then
        ok "sha256 verifies: $checksum_file"
      else
        miss "sha256 verifies: $checksum_file"
      fi
    else
      miss "sha256 file exists: $checksum_file"
    fi

    sig_file="$iso.sig"
    if [[ -f "$sig_file" ]]; then
      ok "signature artifact exists: $sig_file"
    else
      miss "signature artifact exists: $sig_file"
    fi
  done < <(find "$KAKKU_ISO_OUT_DIR" -type f -name '*.iso' -print0)

  if (( iso_count == 0 )); then
    if (( ALLOW_MISSING_ISO )); then
      warn "no ISO artifacts found in $KAKKU_ISO_OUT_DIR"
    else
      miss "at least one ISO artifact exists in $KAKKU_ISO_OUT_DIR"
    fi
  fi
}

manifest_value() {
  local file="$1"
  local key="$2"

  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

check_manifest_file() {
  local manifest="$1"
  local scope="$2"
  local dirty
  local repo_mode
  local repo_server

  if [[ ! -f "$manifest" ]]; then
    miss "$scope manifest exists: $manifest"
    return
  fi

  ok "$scope manifest exists"

  for key in \
    generated_at_utc \
    kakku_commit \
    kakku_worktree_dirty \
    cachyos_live_iso_commit \
    cachyos_build_profile \
    kakku_repo_name \
    kakku_repo_mode \
    kakku_repo_server \
    kakku_repo_siglevel
  do
    if grep -q "^$key=" "$manifest"; then
      ok "$scope manifest records $key"
    else
      miss "$scope manifest records $key"
    fi
  done

  dirty="$(manifest_value "$manifest" kakku_worktree_dirty)"
  if [[ "$dirty" == "yes" ]]; then
    if (( ALLOW_DIRTY_SOURCE )); then
      warn "$scope manifest records dirty KakkuOS worktree"
    else
      miss "$scope manifest records clean KakkuOS worktree"
    fi
  elif [[ "$dirty" == "no" ]]; then
    ok "$scope manifest records clean KakkuOS worktree"
  else
    warn "$scope manifest dirty state is unknown"
  fi

  repo_mode="$(manifest_value "$manifest" kakku_repo_mode)"
  repo_server="$(manifest_value "$manifest" kakku_repo_server)"
  if (( REQUIRE_HOSTED_REPO )); then
    if [[ "$repo_mode" == "hosted" && "$repo_server" != file://* ]]; then
      ok "$scope manifest records hosted Kakku repo"
    else
      miss "$scope manifest records hosted Kakku repo"
    fi
  fi
}

check_manifests() {
  check_manifest_file "$KAKKU_STAGING_DIR/$KAKKU_ISO_MANIFEST_NAME" "staging"

  if [[ -d "$KAKKU_ISO_OUT_DIR" ]]; then
    if find "$KAKKU_ISO_OUT_DIR" -type f -name '*.iso' -print -quit | grep -q .; then
      check_manifest_file "$KAKKU_ISO_OUT_DIR/$KAKKU_ISO_MANIFEST_NAME" "output"
    elif [[ -f "$KAKKU_ISO_OUT_DIR/$KAKKU_ISO_MANIFEST_NAME" ]]; then
      warn "output manifest exists but no ISO artifact was found"
    fi
  fi
}

check_vm_tools() {
  if have_command qemu-system-x86_64; then
    ok "QEMU is available for VM boot tests"
  elif (( ALLOW_MISSING_VM_TOOLS )); then
    warn "QEMU is missing; VM boot/install tests cannot run here"
  else
    miss "QEMU is available for VM boot tests: missing command qemu-system-x86_64"
  fi

  if [[ -x "$REPO_ROOT/scripts/iso-vm-boot.sh" ]]; then
    ok "VM boot helper is executable"
  else
    miss "VM boot helper is executable"
  fi
}

check_host_preflight() {
  local args=()

  if (( ! ALLOW_MISSING_VM_TOOLS )); then
    args+=(--require-vm-tools --require-uefi)
  fi

  if "$REPO_ROOT/scripts/iso-host-preflight.sh" "${args[@]}"; then
    ok "ISO host preflight"
  else
    miss "ISO host preflight"
  fi
}

if (( CHECK_HOST_PREFLIGHT )); then
  check_host_preflight
fi

check_staging_smoke
check_target_hook
check_upstream_cache_clean
check_iso_artifacts
check_manifests
check_vm_tools

if (( failures )); then
  echo
  echo "ISO release audit failed with $warnings warning(s)."
  exit 1
fi

echo
echo "ISO release audit passed with $warnings warning(s)."
