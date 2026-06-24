#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKOUT_DIR="$REPO_ROOT/iso/.cache/cachyos-live-iso"
PROFILE="${CACHYOS_BUILD_PROFILE:-desktop}"
ALLOW_MISSING_LOCAL_REPO=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Validate a staged CachyOS-Live-ISO checkout after iso/build-kakku-iso.sh --prepare-only.

Options:
  --dir PATH                   CachyOS-Live-ISO checkout or archiso profile path.
                               Default: iso/.cache/cachyos-live-iso.
  --profile NAME               Profile name used for package list lookup. Default: desktop.
  --allow-missing-local-repo   Do not fail when [kakku-local] is absent.
  -h, --help                   Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      CHECKOUT_DIR="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --allow-missing-local-repo)
      ALLOW_MISSING_LOCAL_REPO=1
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

miss() {
  printf 'miss %s\n' "$*"
  failures=1
}

warn() {
  printf 'warn %s\n' "$*"
  warnings=$((warnings + 1))
}

check_file() {
  local path="$1"

  if [[ -f "$path" ]]; then
    ok "file: $path"
  else
    miss "file: $path"
  fi
}

check_exec() {
  local path="$1"

  if [[ -x "$path" ]]; then
    ok "executable: $path"
  else
    miss "executable: $path"
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    miss "$label: missing file $path"
  elif grep -Eq "$pattern" "$path"; then
    ok "$label"
  else
    miss "$label"
  fi
}

check_not_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    miss "$label: missing file $path"
  elif grep -Eq "$pattern" "$path"; then
    miss "$label"
  else
    ok "$label"
  fi
}

read_package_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    awk '
      {
        sub(/[[:space:]]*#.*/, "")
        for (i = 1; i <= NF; i++) {
          print $i
        }
      }
    ' "$file"
  fi
}

check_package() {
  local path="$1"
  local package="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    miss "$label: missing file $path"
  elif read_package_file "$path" | grep -Fxq "$package"; then
    ok "$label"
  else
    miss "$label"
  fi
}

check_no_package_matching() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$path" ]]; then
    miss "$label: missing file $path"
  elif read_package_file "$path" | grep -Eq "$pattern"; then
    miss "$label"
  else
    ok "$label"
  fi
}

find_archiso_dir() {
  local candidate
  local candidates=(
    "$CHECKOUT_DIR/archiso"
    "$CHECKOUT_DIR/$PROFILE"
    "$CHECKOUT_DIR"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate/airootfs" && -f "$candidate/pacman.conf" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

find_packages_file() {
  local archiso_dir="$1"
  local candidate
  local candidates=(
    "$archiso_dir/packages_${PROFILE}.x86_64"
    "$archiso_dir/packages.x86_64"
    "$archiso_dir/packages_desktop.x86_64"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

json_field_equals() {
  local file="$1"
  local key="$2"
  local expected="$3"

  if command -v jq >/dev/null 2>&1; then
    jq -e --arg key "$key" --arg expected "$expected" '.[$key] == $expected' "$file" >/dev/null 2>&1
  else
    grep -Eq "\"$key\"[[:space:]]*:[[:space:]]*\"$expected\"" "$file"
  fi
}

archiso_dir="$(find_archiso_dir || true)"
if [[ -z "$archiso_dir" ]]; then
  echo "Could not find a staged archiso profile in $CHECKOUT_DIR." >&2
  exit 1
fi

airootfs="$archiso_dir/airootfs"
packages_file="$(find_packages_file "$archiso_dir" || true)"

ok "archiso profile: $archiso_dir"

if [[ -z "$packages_file" ]]; then
  miss "package list for profile: $PROFILE"
else
  ok "package list: $packages_file"
  check_package "$packages_file" "kakku-desktop" "kakku-desktop is in package list"
  check_package "$packages_file" "cachyos-cli-installer-new" "CLI installer package is in package list"
  check_no_package_matching "$packages_file" '^(calamares|cachyos-calamares.*|cachyos-hello|cachyos-welcome)$' "GUI installer packages removed"
fi

if (( ALLOW_MISSING_LOCAL_REPO )); then
  if grep -q '^\[kakku-local\]$' "$archiso_dir/pacman.conf" 2>/dev/null; then
    ok "local repo configured in profile pacman.conf"
  else
    warn "local repo missing from profile pacman.conf"
  fi
else
  check_contains "$archiso_dir/pacman.conf" '^\[kakku-local\]$' "local repo configured in profile pacman.conf"
  check_contains "$archiso_dir/pacman.conf" '^Server = file://.+' "profile pacman.conf uses a file repo path"
  check_not_contains "$archiso_dir/pacman.conf" '^Server = file:///opt/kakkuos/repo$' "profile pacman.conf does not use live-only repo path"
  check_contains "$airootfs/etc/pacman.conf" '^\[kakku-local\]$' "local repo configured in live pacman.conf"
  check_contains "$airootfs/etc/pacman.conf" '^Server = file:///opt/kakkuos/repo$' "live pacman.conf uses live repo path"
  check_file "$airootfs/opt/kakkuos/repo/kakku-local.db"
fi

check_exec "$airootfs/usr/local/bin/kakku-install"
check_contains "$airootfs/usr/local/bin/kakku-install" 'installer_bin="cachyos-installer"' "installer wrapper prefers cachyos-installer"
check_contains "$airootfs/usr/local/bin/kakku-install" 'installer_bin="install_cachyos"' "installer wrapper has legacy installer fallback"
check_contains "$airootfs/usr/local/bin/kakku-install" '^run_target_install\(\)' "installer wrapper has Kakku target fallback"
check_contains "$airootfs/usr/local/bin/kakku-install" '^run_target_install$' "installer wrapper runs Kakku target fallback"
check_exec "$airootfs/usr/local/bin/kakku-target-install"
check_contains "$airootfs/usr/local/bin/kakku-target-install" '^\[kakku-local\]$' "target installer adds local repo to target pacman.conf"
check_contains "$airootfs/usr/local/bin/kakku-target-install" '^Server = file:///opt/kakkuos/repo$' "target installer uses target-local repo path"
check_file "$airootfs/opt/kakkuos/install.sh"
check_file "$airootfs/usr/share/backgrounds/kakku/wallpaper.png"
check_file "$airootfs/usr/share/backgrounds/kakku/kakku-default.png"
check_file "$airootfs/usr/share/kakku/branding/logo.png"
check_file "$airootfs/usr/share/pixmaps/kakku-logo.png"

settings_file="$airootfs/usr/share/kakku/installer/settings.json"
check_file "$settings_file"
if [[ -f "$settings_file" ]]; then
  for pair in \
    hostname:kakkuos \
    user_shell:/usr/bin/fish \
    desktop:niri \
    post_install:/usr/local/bin/kakku-target-install
  do
    key="${pair%%:*}"
    expected="${pair#*:}"
    if json_field_equals "$settings_file" "$key" "$expected"; then
      ok "installer setting: $key=$expected"
    else
      miss "installer setting: $key=$expected"
    fi
  done
fi

check_contains "$airootfs/etc/os-release" '^NAME="KakkuOS"[[:space:]]*$' "live /etc/os-release is KakkuOS"
check_contains "$airootfs/etc/os-release" '^ID=kakkuos[[:space:]]*$' "live /etc/os-release ID is kakkuos"
check_contains "$airootfs/usr/lib/os-release" '^NAME="KakkuOS"[[:space:]]*$' "live /usr/lib/os-release is KakkuOS"
check_file "$airootfs/etc/kakku-release"
if [[ -e "$airootfs/etc/cachyos-release" ]]; then
  miss "CachyOS release marker removed"
else
  ok "CachyOS release marker removed"
fi
check_contains "$airootfs/etc/hostname" '^kakkuos$' "live hostname is kakkuos"

default_target="$airootfs/etc/systemd/system/default.target"
if [[ -L "$default_target" && "$(readlink "$default_target")" == "/usr/lib/systemd/system/multi-user.target" ]]; then
  ok "live ISO boots to CLI target"
else
  miss "live ISO boots to CLI target"
fi

check_contains "$archiso_dir/profiledef.sh" '(^|[[:space:]])iso_label="KAKKU_' "profile label is KakkuOS"
check_contains "$archiso_dir/profiledef.sh" '(^|[[:space:]])iso_publisher="KakkuOS ' "profile publisher is KakkuOS"
check_contains "$archiso_dir/profiledef.sh" '(^|[[:space:]])iso_application="KakkuOS ' "profile application is KakkuOS"

boot_branding_hits=0
for boot_dir in grub efiboot syslinux; do
  [[ -d "$archiso_dir/$boot_dir" ]] || continue
  if grep -RInE 'CachyOS|CACHYOS' "$archiso_dir/$boot_dir" >/dev/null 2>&1; then
    boot_branding_hits=1
  fi
done

if (( boot_branding_hits )); then
  miss "boot menu user-facing CachyOS branding removed"
else
  ok "boot menu user-facing CachyOS branding removed"
fi

if (( failures )); then
  echo
  echo "ISO smoke check failed."
  exit 1
fi

echo
echo "ISO smoke check passed with $warnings warning(s)."
