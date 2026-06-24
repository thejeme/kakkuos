#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAKKU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHYOS_LIVE_ISO_REPO="${CACHYOS_LIVE_ISO_REPO:-https://github.com/CachyOS/CachyOS-Live-ISO.git}"
CACHYOS_LIVE_ISO_REF="${CACHYOS_LIVE_ISO_REF:-master}"
CACHYOS_LIVE_ISO_DIR="${CACHYOS_LIVE_ISO_DIR:-$SCRIPT_DIR/.cache/cachyos-live-iso}"
CACHYOS_BUILD_PROFILE="${CACHYOS_BUILD_PROFILE:-desktop}"
KAKKU_REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
KAKKU_LOCAL_REPO_DIR="${KAKKU_LOCAL_REPO_DIR:-$KAKKU_ROOT/packaging/repo}"
KAKKU_ISO_OUT_DIR="${KAKKU_ISO_OUT_DIR:-$SCRIPT_DIR/out}"
KAKKU_CLI_INSTALLER_PACKAGE="${KAKKU_CLI_INSTALLER_PACKAGE:-cachyos-cli-installer-new}"
KAKKU_CLI_INSTALLER_BIN="${KAKKU_CLI_INSTALLER_BIN:-cachyos-installer}"
KAKKU_BUILDISO_ARGS="${KAKKU_BUILDISO_ARGS:--v -w}"

prepare_only=0
clean=0
skip_local_repo=0
use_existing_local_repo=0
skip_restore=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --prepare-only       Clone/update CachyOS-Live-ISO and stage KakkuOS without building.
  --clean              Remove the cached CachyOS-Live-ISO checkout before preparing.
  --repo URL           CachyOS-Live-ISO git URL.
  --ref REF            CachyOS-Live-ISO branch, tag, or commit. Default: master.
  --dir PATH           CachyOS-Live-ISO checkout path. Default: iso/.cache/cachyos-live-iso.
  --out DIR            Copy produced ISO artifacts here. Default: iso/out.
  --skip-local-repo    Do not build/inject the local KakkuOS package repo.
  --use-existing-local-repo
                       Inject KAKKU_LOCAL_REPO_DIR without rebuilding it first.
  --skip-restore       Do not restore CachyOS files from KakkuOS backups before staging.
  -h, --help           Show this help.

Environment:
  CACHYOS_LIVE_ISO_REPO
  CACHYOS_LIVE_ISO_REF
  CACHYOS_LIVE_ISO_DIR
  CACHYOS_BUILD_PROFILE
  KAKKU_LOCAL_REPO_DIR
  KAKKU_ISO_OUT_DIR
  KAKKU_REPO_NAME
  KAKKU_CLI_INSTALLER_PACKAGE
  KAKKU_CLI_INSTALLER_BIN
  KAKKU_BUILDISO_ARGS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare-only)
      prepare_only=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    --repo)
      CACHYOS_LIVE_ISO_REPO="$2"
      shift 2
      ;;
    --ref)
      CACHYOS_LIVE_ISO_REF="$2"
      shift 2
      ;;
    --dir)
      CACHYOS_LIVE_ISO_DIR="$2"
      shift 2
      ;;
    --out)
      KAKKU_ISO_OUT_DIR="$2"
      shift 2
      ;;
    --skip-local-repo)
      skip_local_repo=1
      shift
      ;;
    --use-existing-local-repo)
      use_existing_local_repo=1
      shift
      ;;
    --skip-restore)
      skip_restore=1
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

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
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

relative_to_archiso() {
  local archiso_dir="$1"
  local path="$2"

  printf '%s\n' "${path#"$archiso_dir"/}"
}

backup_path_for() {
  local archiso_dir="$1"
  local path="$2"
  local rel

  rel="$(relative_to_archiso "$archiso_dir" "$path")"
  printf '%s/.kakku-originals/%s\n' "$archiso_dir" "$rel"
}

restore_mutable_file() {
  local archiso_dir="$1"
  local path="$2"
  local backup

  backup="$(backup_path_for "$archiso_dir" "$path")"
  if [[ -f "$backup" && "$skip_restore" != "1" ]]; then
    install -Dm644 "$backup" "$path"
  fi
}

remember_mutable_file() {
  local archiso_dir="$1"
  local path="$2"
  local backup

  backup="$(backup_path_for "$archiso_dir" "$path")"
  if [[ -f "$path" && ! -f "$backup" ]]; then
    install -Dm644 "$path" "$backup"
  fi
}

find_archiso_dir() {
  local candidate
  local candidates=(
    "$CACHYOS_LIVE_ISO_DIR/archiso"
    "$CACHYOS_LIVE_ISO_DIR/$CACHYOS_BUILD_PROFILE"
    "$CACHYOS_LIVE_ISO_DIR"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate/airootfs" && -f "$candidate/pacman.conf" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "Could not find a CachyOS archiso profile directory in $CACHYOS_LIVE_ISO_DIR." >&2
  echo "Expected a directory with airootfs/ and pacman.conf." >&2
  exit 1
}

find_packages_file() {
  local archiso_dir="$1"
  local candidate
  local candidates=(
    "$archiso_dir/packages_${CACHYOS_BUILD_PROFILE}.x86_64"
    "$archiso_dir/packages.x86_64"
    "$archiso_dir/packages_desktop.x86_64"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "Could not find an archiso package list for profile '$CACHYOS_BUILD_PROFILE'." >&2
  echo "Checked:" >&2
  printf '  %s\n' "${candidates[@]}" >&2
  exit 1
}

read_kakku_repo_packages() {
  read_package_file "$KAKKU_ROOT/packages/pacman.txt"

  if [[ -d "$KAKKU_ROOT/packages/profiles" ]]; then
    for package_file in "$KAKKU_ROOT"/packages/profiles/*.txt; do
      [[ -f "$package_file" ]] || continue
      read_package_file "$package_file"
    done
  fi
}

build_local_repo() {
  if (( skip_local_repo || use_existing_local_repo )); then
    return
  fi

  "$KAKKU_ROOT/packaging/build-local-repo.sh" \
    --output "$KAKKU_LOCAL_REPO_DIR" \
    --repo-name "$KAKKU_REPO_NAME" \
    --include-aur-hard-deps
}

clone_or_update_cachyos_live_iso() {
  if (( clean )) && [[ -d "$CACHYOS_LIVE_ISO_DIR" ]]; then
    rm -rf "$CACHYOS_LIVE_ISO_DIR"
  fi

  if [[ -d "$CACHYOS_LIVE_ISO_DIR/.git" ]]; then
    git -C "$CACHYOS_LIVE_ISO_DIR" fetch --prune origin
  else
    mkdir -p "$(dirname "$CACHYOS_LIVE_ISO_DIR")"
    git clone "$CACHYOS_LIVE_ISO_REPO" "$CACHYOS_LIVE_ISO_DIR"
  fi

  git -C "$CACHYOS_LIVE_ISO_DIR" checkout "$CACHYOS_LIVE_ISO_REF"
}

append_unique_packages() {
  local target="$1"
  shift
  local tmp

  tmp="$(mktemp)"
  {
    read_package_file "$target"
    printf '%s\n' "$@"
  } | awk '!seen[$0]++' > "$tmp"
  mv "$tmp" "$target"
}

remove_gui_installer_packages() {
  local target="$1"
  local tmp

  tmp="$(mktemp)"
  read_package_file "$target" |
    grep -Ev '^(calamares|cachyos-calamares.*|cachyos-hello|cachyos-welcome)$' > "$tmp" || true
  mv "$tmp" "$target"
}

configure_cli_live_environment() {
  local airootfs="$1"

  install -dm755 "$airootfs/etc/systemd/system"
  ln -sfn /usr/lib/systemd/system/multi-user.target "$airootfs/etc/systemd/system/default.target"

  install -dm755 "$airootfs/etc/systemd/system/getty@tty1.service.d"
  install -m644 /dev/stdin "$airootfs/etc/systemd/system/getty@tty1.service.d/override.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin liveuser --noclear %I $TERM
EOF
}

replace_in_file() {
  local file="$1"
  shift

  [[ -f "$file" ]] || return 0
  sed -i "$@" "$file"
}

apply_text_branding() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  replace_in_file "$file" \
    -e 's/CachyOS/KakkuOS/g' \
    -e 's/cachyos/kakkuos/g' \
    -e 's/CACHYOS/KAKKUOS/g'
}

write_live_identity() {
  local airootfs="$1"

  install -m644 "$KAKKU_ROOT/system/os-release" "$airootfs/etc/os-release"
  install -m644 "$KAKKU_ROOT/system/os-release" "$airootfs/usr/lib/os-release"
  install -m644 "$KAKKU_ROOT/system/os-release" "$airootfs/usr/share/kakku/os-release"

  printf 'KakkuOS Live\n' > "$airootfs/etc/kakku-release"
  rm -f "$airootfs/etc/cachyos-release"
  printf 'kakkuos\n' > "$airootfs/etc/hostname"
}

brand_boot_entries() {
  local archiso_dir="$1"

  apply_text_branding "$archiso_dir/grub/grub.cfg"
  apply_text_branding "$archiso_dir/grub/loopback.cfg"
  apply_text_branding "$archiso_dir/efiboot/loader/loader.conf"
  apply_text_branding "$archiso_dir/efiboot/loader/entries/01-archiso-linux.conf"
  apply_text_branding "$archiso_dir/efiboot/loader/entries/02-archiso-linux-cachyos.conf"
  apply_text_branding "$archiso_dir/efiboot/loader/entries/fallback.conf"
  apply_text_branding "$archiso_dir/syslinux/archiso_head.cfg"
  apply_text_branding "$archiso_dir/syslinux/archiso_pxe-linux.cfg"
  apply_text_branding "$archiso_dir/syslinux/archiso_pxe.cfg"
  apply_text_branding "$archiso_dir/syslinux/archiso_sys-linux.cfg"
  apply_text_branding "$archiso_dir/syslinux/archiso_sys.cfg"
  apply_text_branding "$archiso_dir/syslinux/archiso_tail.cfg"
  apply_text_branding "$archiso_dir/syslinux/syslinux.cfg"
}

brand_profile_definition() {
  local profiledef="$1"

  [[ -f "$profiledef" ]] || return 0

  set_profiledef_assignment() {
    local name="$1"
    local value="$2"
    local escaped_value

    escaped_value="${value//\\/\\\\}"
    escaped_value="${escaped_value//&/\\&}"
    escaped_value="${escaped_value//#/\\#}"

    if grep -Eq "(^|[[:space:]])${name}=" "$profiledef"; then
      sed -i -E "s#(^|[[:space:]])${name}=\"[^\"]*\"#\\1${name}=\"${escaped_value}\"#" "$profiledef"
    else
      printf '%s="%s"\n' "$name" "$value" >> "$profiledef"
    fi
  }

  set_profiledef_assignment "iso_label" 'KAKKU_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)'
  set_profiledef_assignment "iso_publisher" 'KakkuOS <https://kakkuos.jeme.app/>'
  set_profiledef_assignment "iso_application" 'KakkuOS Live/Rescue ISO'
}

patch_cachyos_build_helpers() {
  local live_iso_dir="$1"
  local util_iso="$live_iso_dir/util-iso.sh"

  [[ -f "$util_iso" ]] || return 0

  cat >> "$util_iso" <<'EOF'

# KakkuOS live ISO branding override. Appended by iso/build-kakku-iso.sh.
generate_motd() {
    cat << 'MOTD' > ${src_dir}/archiso/airootfs/etc/motd
KakkuOS live environment

This ISO is based on CachyOS live ISO tooling and installs KakkuOS.
Run kakku-install to start the CLI installer.

KakkuOS sources:
https://github.com/TheJeme/kakkuos

Upstream CachyOS Live ISO sources:
https://github.com/CachyOS/CachyOS-Live-ISO
MOTD
}

gen_iso_fn() {
    local vars=() name
    vars+=("kakkuos")
    [[ -n ${profile} ]] && vars+=("${profile}")
    vars+=("linux")
    vars+=("$(date +%y%m%d)")

    for n in ${vars[@]}; do
        name=${name:-}${name:+-}${n}
    done

    echo $name
}
EOF
}

remember_branding_files() {
  local archiso_dir="$1"
  local airootfs="$2"
  local file
  local files=(
    "$airootfs/etc/os-release"
    "$airootfs/usr/lib/os-release"
    "$airootfs/etc/cachyos-release"
    "$airootfs/etc/hostname"
    "$airootfs/etc/motd"
    "$archiso_dir/grub/grub.cfg"
    "$archiso_dir/grub/loopback.cfg"
    "$archiso_dir/efiboot/loader/loader.conf"
    "$archiso_dir/efiboot/loader/entries/01-archiso-linux.conf"
    "$archiso_dir/efiboot/loader/entries/02-archiso-linux-cachyos.conf"
    "$archiso_dir/efiboot/loader/entries/fallback.conf"
    "$archiso_dir/syslinux/archiso_head.cfg"
    "$archiso_dir/syslinux/archiso_pxe-linux.cfg"
    "$archiso_dir/syslinux/archiso_pxe.cfg"
    "$archiso_dir/syslinux/archiso_sys-linux.cfg"
    "$archiso_dir/syslinux/archiso_sys.cfg"
    "$archiso_dir/syslinux/archiso_tail.cfg"
    "$archiso_dir/syslinux/syslinux.cfg"
    "$archiso_dir/profiledef.sh"
  )

  for file in "${files[@]}"; do
    remember_mutable_file "$archiso_dir" "$file"
  done
}

restore_branding_files() {
  local archiso_dir="$1"
  local airootfs="$2"
  local file
  local files=(
    "$airootfs/etc/os-release"
    "$airootfs/usr/lib/os-release"
    "$airootfs/etc/cachyos-release"
    "$airootfs/etc/hostname"
    "$airootfs/etc/motd"
    "$archiso_dir/grub/grub.cfg"
    "$archiso_dir/grub/loopback.cfg"
    "$archiso_dir/efiboot/loader/loader.conf"
    "$archiso_dir/efiboot/loader/entries/01-archiso-linux.conf"
    "$archiso_dir/efiboot/loader/entries/02-archiso-linux-cachyos.conf"
    "$archiso_dir/efiboot/loader/entries/fallback.conf"
    "$archiso_dir/syslinux/archiso_head.cfg"
    "$archiso_dir/syslinux/archiso_pxe-linux.cfg"
    "$archiso_dir/syslinux/archiso_pxe.cfg"
    "$archiso_dir/syslinux/archiso_sys-linux.cfg"
    "$archiso_dir/syslinux/archiso_sys.cfg"
    "$archiso_dir/syslinux/archiso_tail.cfg"
    "$archiso_dir/syslinux/syslinux.cfg"
    "$archiso_dir/profiledef.sh"
  )

  for file in "${files[@]}"; do
    restore_mutable_file "$archiso_dir" "$file"
  done
}

apply_iso_branding() {
  local archiso_dir="$1"
  local airootfs="$2"

  write_live_identity "$airootfs"
  brand_boot_entries "$archiso_dir"
  brand_profile_definition "$archiso_dir/profiledef.sh"
  patch_cachyos_build_helpers "$CACHYOS_LIVE_ISO_DIR"
}

install_cli_installer_entrypoint() {
  local airootfs="$1"

  install -dm755 "$airootfs/usr/local/bin"
  install -m755 /dev/stdin "$airootfs/usr/local/bin/kakku-install" <<EOF
#!/usr/bin/env bash
set -euo pipefail

installer_bin="$KAKKU_CLI_INSTALLER_BIN"
if ! command -v "\$installer_bin" >/dev/null 2>&1; then
  if command -v install_cachyos >/dev/null 2>&1; then
    installer_bin="install_cachyos"
  else
    echo "Missing CLI installer binary: $KAKKU_CLI_INSTALLER_BIN" >&2
    exit 1
  fi
fi

cd /usr/share/kakku/installer

run_installer() {
  if (( EUID == 0 )); then
    "\$installer_bin" "\$@"
    return
  fi

  sudo "\$installer_bin" "\$@"
}

run_target_install() {
  local target="\${KAKKU_TARGET_MOUNT:-/mnt}"

  if [[ ! -x /usr/local/bin/kakku-target-install ]]; then
    echo "Missing KakkuOS target installer: /usr/local/bin/kakku-target-install" >&2
    return 1
  fi

  if [[ ! -d "\$target/etc" ]]; then
    echo "KakkuOS target install skipped: \$target does not look mounted."
    return 0
  fi

  if (( EUID == 0 )); then
    KAKKU_TARGET_MOUNT="\$target" /usr/local/bin/kakku-target-install
    return
  fi

  sudo env KAKKU_TARGET_MOUNT="\$target" /usr/local/bin/kakku-target-install
}

run_installer "\$@"
run_target_install
EOF

  install -dm755 "$airootfs/etc/profile.d"
  install -m644 /dev/stdin "$airootfs/etc/profile.d/kakku-installer.sh" <<'EOF'
if [ -z "${KAKKU_INSTALLER_HINT_SHOWN:-}" ] && [ -t 1 ]; then
  export KAKKU_INSTALLER_HINT_SHOWN=1
  printf '\nKakkuOS installer: run %s to start the CLI installer.\n\n' "kakku-install"
fi
EOF

  install -m644 /dev/stdin "$airootfs/etc/motd" <<'EOF'
KakkuOS live environment

Run kakku-install to start the CLI installer.
EOF
}

install_cli_installer_config() {
  local airootfs="$1"

  install -dm755 "$airootfs/usr/share/kakku/installer"
  install -m644 /dev/stdin "$airootfs/usr/share/kakku/installer/settings.json" <<'EOF'
{
  "menus": 2,
  "headless_mode": false,
  "server_mode": false,
  "fs_name": "btrfs",
  "hostname": "kakkuos",
  "locale": "en_US",
  "xkbmap": "us",
  "timezone": "UTC",
  "user_shell": "/usr/bin/fish",
  "kernel": "linux-cachyos",
  "desktop": "niri",
  "bootloader": "limine",
  "post_install": "/usr/local/bin/kakku-target-install"
}
EOF

  install -m755 /dev/stdin "$airootfs/usr/local/bin/kakku-target-install" <<EOF
#!/usr/bin/env bash
set -euo pipefail

target="\${KAKKU_TARGET_MOUNT:-/mnt}"
repo_source="/opt/kakkuos/repo"
repo_target="\$target/opt/kakkuos/repo"
target_pacman_conf="\$target/etc/pacman.conf"

if [[ ! -d "\$target/etc" ]]; then
  echo "KakkuOS target install skipped: \$target does not look mounted." >&2
  exit 1
fi

if [[ -d "\$repo_source" ]]; then
  mkdir -p "\$repo_target"
  rsync -a --delete "\$repo_source/" "\$repo_target/"

  if ! grep -q '^\[$KAKKU_REPO_NAME\]$' "\$target_pacman_conf"; then
    cat <<'REPO' >> "\$target_pacman_conf"

[$KAKKU_REPO_NAME]
SigLevel = Optional TrustAll
Server = file:///opt/kakkuos/repo
REPO
  fi
fi

arch-chroot "\$target" pacman -Syu --needed --noconfirm kakku-desktop

arch-chroot "\$target" systemctl disable sddm.service 2>/dev/null || true
arch-chroot "\$target" systemctl disable ly.service 2>/dev/null || true
arch-chroot "\$target" systemctl enable greetd.service
arch-chroot "\$target" systemctl enable NetworkManager.service 2>/dev/null || true
arch-chroot "\$target" systemctl enable bluetooth.service 2>/dev/null || true
arch-chroot "\$target" systemctl enable power-profiles-daemon.service 2>/dev/null || true

echo "KakkuOS target packages and services applied."
EOF
}

inject_local_repo() {
  local archiso_dir="$1"
  local airootfs="$2"
  local repo_target="$airootfs/opt/kakkuos/repo"
  local pacman_conf="$archiso_dir/pacman.conf"
  local live_pacman_conf="$airootfs/etc/pacman.conf"
  local local_repo_abs

  if (( skip_local_repo )); then
    echo "Skipping local KakkuOS package repo injection."
    return
  fi

  if [[ ! -d "$KAKKU_LOCAL_REPO_DIR" ]]; then
    echo "Missing local KakkuOS package repo: $KAKKU_LOCAL_REPO_DIR" >&2
    echo "Run packaging/build-local-repo.sh first, or rerun without --skip-local-repo." >&2
    exit 1
  fi

  local_repo_abs="$(cd "$KAKKU_LOCAL_REPO_DIR" && pwd)"

  mkdir -p "$repo_target"
  rsync -a --delete "$KAKKU_LOCAL_REPO_DIR/" "$repo_target/"

  append_repo_stanza() {
    local target_conf="$1"
    local server="$2"

    if ! grep -q "^\[$KAKKU_REPO_NAME\]$" "$target_conf"; then
      cat <<EOF >> "$target_conf"

[$KAKKU_REPO_NAME]
SigLevel = Optional TrustAll
Server = $server
EOF
    fi
  }

  append_repo_stanza "$pacman_conf" "file://$local_repo_abs"
  if [[ -f "$live_pacman_conf" ]]; then
    append_repo_stanza "$live_pacman_conf" "file:///opt/kakkuos/repo"
  fi
}

stage_kakkuos() {
  local archiso_dir
  archiso_dir="$(find_archiso_dir)"
  local airootfs="$archiso_dir/airootfs"
  local packages_file
  packages_file="$(find_packages_file "$archiso_dir")"
  local staged_source="$airootfs/opt/kakkuos"

  remember_mutable_file "$archiso_dir" "$packages_file"
  remember_mutable_file "$archiso_dir" "$archiso_dir/pacman.conf"
  remember_mutable_file "$archiso_dir" "$airootfs/etc/pacman.conf"
  remember_mutable_file "$archiso_dir" "$CACHYOS_LIVE_ISO_DIR/util-iso.sh"
  remember_branding_files "$archiso_dir" "$airootfs"
  restore_mutable_file "$archiso_dir" "$packages_file"
  restore_mutable_file "$archiso_dir" "$archiso_dir/pacman.conf"
  restore_mutable_file "$archiso_dir" "$airootfs/etc/pacman.conf"
  restore_mutable_file "$archiso_dir" "$CACHYOS_LIVE_ISO_DIR/util-iso.sh"
  restore_branding_files "$archiso_dir" "$airootfs"

  mkdir -p "$staged_source"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.agents' \
    --exclude '.codex' \
    --exclude 'packaging/repo' \
    --exclude 'iso/.cache' \
    --exclude 'iso/out' \
    "$KAKKU_ROOT/" "$staged_source/"

  install -dm755 "$airootfs/usr/share/kakku/branding"
  rsync -a --delete "$KAKKU_ROOT/branding/" "$airootfs/usr/share/kakku/branding/"
  install -Dm644 "$KAKKU_ROOT/branding/logo.png" "$airootfs/usr/share/pixmaps/kakku-logo.png"
  if [[ -d "$KAKKU_ROOT/backgrounds" ]]; then
    install -dm755 "$airootfs/usr/share/backgrounds/kakku"
    rsync -a --delete "$KAKKU_ROOT/backgrounds/" "$airootfs/usr/share/backgrounds/kakku/"
  fi
  install -Dm644 "$KAKKU_ROOT/branding/wallpaper.png" "$airootfs/usr/share/backgrounds/kakku/wallpaper.png"
  install -dm755 "$airootfs/usr/share/kakku"

  apply_iso_branding "$archiso_dir" "$airootfs"
  inject_local_repo "$archiso_dir" "$airootfs"
  remove_gui_installer_packages "$packages_file"
  append_unique_packages "$packages_file" kakku-desktop "$KAKKU_CLI_INSTALLER_PACKAGE"
  configure_cli_live_environment "$airootfs"
  install_cli_installer_config "$airootfs"
  install_cli_installer_entrypoint "$airootfs"

  echo "Prepared CachyOS-Live-ISO checkout:"
  echo "  $CACHYOS_LIVE_ISO_DIR"
  echo
  echo "Staged KakkuOS source:"
  echo "  $staged_source"
  echo
  echo "Updated package list:"
  echo "  $packages_file"
  echo
  echo "CLI installer entrypoint:"
  echo "  $airootfs/usr/local/bin/kakku-install"
  if (( ! skip_local_repo )); then
    echo
    echo "Injected local KakkuOS package repo:"
    echo "  $airootfs/opt/kakkuos/repo"
  fi
}

build_iso() {
  cd "$CACHYOS_LIVE_ISO_DIR"
  # shellcheck disable=SC2086
  sudo ./buildiso.sh -p "$CACHYOS_BUILD_PROFILE" $KAKKU_BUILDISO_ARGS
}

copy_iso_outputs() {
  local source_out="$CACHYOS_LIVE_ISO_DIR/out"

  if [[ ! -d "$source_out" ]]; then
    echo "No CachyOS build output directory found at $source_out."
    return
  fi

  mkdir -p "$KAKKU_ISO_OUT_DIR"
  find "$source_out" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.sha256' -o -name '*.sig' \) -exec cp -f {} "$KAKKU_ISO_OUT_DIR/" \;

  echo
  echo "Copied ISO artifacts to:"
  echo "  $KAKKU_ISO_OUT_DIR"
}

require_command git
require_command rsync
require_command sed
require_command awk

build_local_repo
clone_or_update_cachyos_live_iso
stage_kakkuos

if (( prepare_only )); then
  echo
  echo "Prepare-only mode complete. Review the staged CachyOS tree before building."
  exit 0
fi

build_iso
copy_iso_outputs
