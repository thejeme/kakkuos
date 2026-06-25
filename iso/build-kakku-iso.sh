#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAKKU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHYOS_LIVE_ISO_REPO="${CACHYOS_LIVE_ISO_REPO:-https://github.com/CachyOS/CachyOS-Live-ISO.git}"
CACHYOS_LIVE_ISO_REF="${CACHYOS_LIVE_ISO_REF:-master}"
CACHYOS_LIVE_ISO_DIR="${CACHYOS_LIVE_ISO_DIR:-$SCRIPT_DIR/.cache/cachyos-live-iso}"
KAKKU_STAGING_DIR="${KAKKU_STAGING_DIR:-$SCRIPT_DIR/.cache/kakku-live-iso}"
CACHYOS_BUILD_PROFILE="${CACHYOS_BUILD_PROFILE:-desktop}"
KAKKU_REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
KAKKU_REPO_SERVER="${KAKKU_REPO_SERVER:-}"
KAKKU_REPO_SIGLEVEL="${KAKKU_REPO_SIGLEVEL:-Optional TrustAll}"
KAKKU_LOCAL_REPO_DIR="${KAKKU_LOCAL_REPO_DIR:-$KAKKU_ROOT/packaging/repo}"
KAKKU_ISO_OUT_DIR="${KAKKU_ISO_OUT_DIR:-$SCRIPT_DIR/out}"
KAKKU_ISO_MANIFEST_NAME="${KAKKU_ISO_MANIFEST_NAME:-kakku-iso-build-manifest.txt}"
KAKKU_CLI_INSTALLER_PACKAGE="${KAKKU_CLI_INSTALLER_PACKAGE:-cachyos-cli-installer-new}"
KAKKU_CLI_INSTALLER_BIN="${KAKKU_CLI_INSTALLER_BIN:-cachyos-installer}"
KAKKU_BUILDISO_ARGS="${KAKKU_BUILDISO_ARGS:--v -w}"

prepare_only=0
clean=0
skip_local_repo=0
use_existing_local_repo=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --prepare-only       Clone/update CachyOS-Live-ISO and stage KakkuOS without building.
  --clean              Remove the cached CachyOS-Live-ISO checkout before preparing.
  --repo URL           CachyOS-Live-ISO git URL.
  --ref REF            CachyOS-Live-ISO branch, tag, or commit. Default: master.
  --dir PATH           CachyOS-Live-ISO upstream checkout path. Default: iso/.cache/cachyos-live-iso.
  --staging-dir PATH   Mutable KakkuOS staging/build tree. Default: iso/.cache/kakku-live-iso.
  --out DIR            Copy produced ISO artifacts here. Default: iso/out.
  --skip-local-repo    Do not build/inject the local KakkuOS package repo.
                       Intended for prepare-only inspection; full builds need
                       KakkuOS packages from a configured pacman repo.
  --use-existing-local-repo
                       Inject KAKKU_LOCAL_REPO_DIR without rebuilding it first.
  --repo-server URL    Use a hosted KakkuOS pacman repo instead of embedding
                       the local file repo. Example: https://repo.example/kakku
  --repo-siglevel VAL  Pacman SigLevel for the Kakku repo stanza.
                       Default: Optional TrustAll.
  -h, --help           Show this help.

Environment:
  CACHYOS_LIVE_ISO_REPO
  CACHYOS_LIVE_ISO_REF
  CACHYOS_LIVE_ISO_DIR
  KAKKU_STAGING_DIR
  CACHYOS_BUILD_PROFILE
  KAKKU_REPO_SERVER
  KAKKU_REPO_SIGLEVEL
  KAKKU_LOCAL_REPO_DIR
  KAKKU_ISO_OUT_DIR
  KAKKU_ISO_MANIFEST_NAME
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
    --staging-dir)
      KAKKU_STAGING_DIR="$2"
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
    --repo-server)
      KAKKU_REPO_SERVER="$2"
      shift 2
      ;;
    --repo-siglevel)
      KAKKU_REPO_SIGLEVEL="$2"
      shift 2
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

find_archiso_dir() {
  local candidate
  local candidates=(
    "$KAKKU_STAGING_DIR/archiso"
    "$KAKKU_STAGING_DIR/$CACHYOS_BUILD_PROFILE"
    "$KAKKU_STAGING_DIR"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate/airootfs" && -f "$candidate/pacman.conf" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "Could not find a staged CachyOS archiso profile directory in $KAKKU_STAGING_DIR." >&2
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

validate_repo_config() {
  case "$KAKKU_REPO_NAME" in
    ""|*[!A-Za-z0-9._-]*)
      echo "Unsupported KAKKU_REPO_NAME: $KAKKU_REPO_NAME" >&2
      echo "Use only letters, numbers, dots, underscores, and hyphens." >&2
      exit 1
      ;;
  esac

  if [[ -n "$KAKKU_REPO_SERVER" ]]; then
    case "$KAKKU_REPO_SERVER" in
      *[[:space:]]*|*'"'*|*'`'*|*'$'*|*'\'*)
        echo "Unsupported characters in KAKKU_REPO_SERVER: $KAKKU_REPO_SERVER" >&2
        echo "Use a plain pacman Server URL without whitespace or shell metacharacters." >&2
        exit 1
        ;;
    esac
  fi

  case "$KAKKU_REPO_SIGLEVEL" in
    *$'\n'*|*$'\r'*|*'"'*|*'`'*|*'$'*|*'\'*)
      echo "Unsupported characters in KAKKU_REPO_SIGLEVEL: $KAKKU_REPO_SIGLEVEL" >&2
      echo "Use a pacman SigLevel value without shell metacharacters." >&2
      exit 1
      ;;
  esac
}

kakku_repo_server() {
  if [[ -n "$KAKKU_REPO_SERVER" ]]; then
    printf '%s\n' "$KAKKU_REPO_SERVER"
  else
    printf '%s\n' "file:///opt/kakkuos/repo"
  fi
}

using_hosted_repo() {
  [[ -n "$KAKKU_REPO_SERVER" ]]
}

build_local_repo() {
  if (( skip_local_repo || use_existing_local_repo )) || using_hosted_repo; then
    return
  fi

  "$KAKKU_ROOT/packaging/build-local-repo.sh" \
    --output "$KAKKU_LOCAL_REPO_DIR" \
    --repo-name "$KAKKU_REPO_NAME" \
    --include-aur-hard-deps
}

git_commit_for() {
  local dir="$1"

  git -C "$dir" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

git_dirty_for() {
  local dir="$1"

  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'unknown\n'
  elif [[ -n "$(git -C "$dir" status --short)" ]]; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

write_iso_manifest() {
  local archiso_dir="$1"
  local airootfs="$2"
  local packages_file="$3"
  local manifest="$KAKKU_STAGING_DIR/$KAKKU_ISO_MANIFEST_NAME"
  local live_manifest="$airootfs/usr/share/kakku/$KAKKU_ISO_MANIFEST_NAME"
  local package

  install -dm755 "$KAKKU_STAGING_DIR"
  {
    printf 'generated_at_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'kakku_root=%s\n' "$KAKKU_ROOT"
    printf 'kakku_commit=%s\n' "$(git_commit_for "$KAKKU_ROOT")"
    printf 'kakku_worktree_dirty=%s\n' "$(git_dirty_for "$KAKKU_ROOT")"
    printf 'cachyos_live_iso_repo=%s\n' "$CACHYOS_LIVE_ISO_REPO"
    printf 'cachyos_live_iso_ref=%s\n' "$CACHYOS_LIVE_ISO_REF"
    printf 'cachyos_live_iso_commit=%s\n' "$(git_commit_for "$CACHYOS_LIVE_ISO_DIR")"
    printf 'cachyos_build_profile=%s\n' "$CACHYOS_BUILD_PROFILE"
    printf 'kakku_repo_name=%s\n' "$KAKKU_REPO_NAME"
    if using_hosted_repo; then
      printf 'kakku_repo_mode=hosted\n'
    else
      printf 'kakku_repo_mode=embedded\n'
    fi
    printf 'kakku_repo_server=%s\n' "$(kakku_repo_server)"
    printf 'kakku_repo_siglevel=%s\n' "$KAKKU_REPO_SIGLEVEL"
    printf 'kakku_cli_installer_package=%s\n' "$KAKKU_CLI_INSTALLER_PACKAGE"
    printf 'kakku_cli_installer_bin=%s\n' "$KAKKU_CLI_INSTALLER_BIN"
    printf 'kakku_staging_dir=%s\n' "$KAKKU_STAGING_DIR"
    printf 'archiso_dir=%s\n' "$archiso_dir"
    printf 'packages_file=%s\n' "$packages_file"
    if [[ -d "$KAKKU_LOCAL_REPO_DIR" ]]; then
      while IFS= read -r package; do
        printf 'local_repo_package=%s\n' "$(basename "$package")"
      done < <(find "$KAKKU_LOCAL_REPO_DIR" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' | sort)
    fi
  } > "$manifest"

  install -Dm644 "$manifest" "$live_manifest"
}

check_full_build_requirements() {
  local missing=0
  local command_name
  local required_commands=(
    sudo
    mkarchiso
    mksquashfs
    pacstrap
  )

  if (( skip_local_repo )) && ! using_hosted_repo; then
    echo "Cannot build a full ISO with --skip-local-repo." >&2
    echo "The staged package list includes kakku-desktop, so pacman needs a KakkuOS package repo." >&2
    echo "Use --repo-server, --use-existing-local-repo, or omit --skip-local-repo for full ISO builds." >&2
    exit 1
  fi

  for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "Missing full ISO build command: $command_name" >&2
      missing=1
    fi
  done

  if (( missing )); then
    echo >&2
    echo "Install the CachyOS/Arch ISO build requirements, then rerun:" >&2
    echo "  sudo pacman -S archiso base-devel mkinitcpio-archiso git pacman-contrib squashfs-tools grub rsync arch-install-scripts --needed" >&2
    exit 1
  fi
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
  git -C "$CACHYOS_LIVE_ISO_DIR" reset --hard "$CACHYOS_LIVE_ISO_REF"
  git -C "$CACHYOS_LIVE_ISO_DIR" clean -fdx
}

prepare_staging_checkout() {
  case "$KAKKU_STAGING_DIR" in
    ""|"/"|"$KAKKU_ROOT"|"$KAKKU_ROOT/"|"$CACHYOS_LIVE_ISO_DIR"|"$CACHYOS_LIVE_ISO_DIR/")
      echo "Refusing unsafe KAKKU_STAGING_DIR: $KAKKU_STAGING_DIR" >&2
      exit 1
      ;;
  esac

  mkdir -p "$KAKKU_STAGING_DIR"
  rsync -a --delete \
    --exclude '.git' \
    "$CACHYOS_LIVE_ISO_DIR/" "$KAKKU_STAGING_DIR/"
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

apply_boot_menu_branding() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  replace_in_file "$file" \
    -e 's/CachyOS/KakkuOS/g'
}

write_live_identity() {
  local airootfs="$1"

  install -Dm644 "$KAKKU_ROOT/system/os-release" "$airootfs/etc/os-release"
  install -Dm644 "$KAKKU_ROOT/system/os-release" "$airootfs/usr/lib/os-release"
  install -Dm644 "$KAKKU_ROOT/system/os-release" "$airootfs/usr/share/kakku/os-release"

  printf 'KakkuOS Live\n' > "$airootfs/etc/kakku-release"
  rm -f "$airootfs/etc/cachyos-release"
  printf 'kakkuos\n' > "$airootfs/etc/hostname"
}

brand_boot_entries() {
  local archiso_dir="$1"

  apply_boot_menu_branding "$archiso_dir/grub/grub.cfg"
  apply_boot_menu_branding "$archiso_dir/grub/loopback.cfg"
  apply_boot_menu_branding "$archiso_dir/efiboot/loader/loader.conf"
  apply_boot_menu_branding "$archiso_dir/efiboot/loader/entries/01-archiso-linux.conf"
  apply_boot_menu_branding "$archiso_dir/efiboot/loader/entries/02-archiso-linux-cachyos.conf"
  apply_boot_menu_branding "$archiso_dir/efiboot/loader/entries/fallback.conf"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_head.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_pxe-linux.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_pxe.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_sys-linux.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_sys.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/archiso_tail.cfg"
  apply_boot_menu_branding "$archiso_dir/syslinux/syslinux.cfg"
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

apply_iso_branding() {
  local archiso_dir="$1"
  local airootfs="$2"

  write_live_identity "$airootfs"
  brand_boot_entries "$archiso_dir"
  brand_profile_definition "$archiso_dir/profiledef.sh"
  patch_cachyos_build_helpers "$KAKKU_STAGING_DIR"
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
  local repo_server
  local repo_embedded

  repo_server="$(kakku_repo_server)"
  repo_embedded=1
  if using_hosted_repo; then
    repo_embedded=0
  fi

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
repo_name="\${KAKKU_REPO_NAME:-$KAKKU_REPO_NAME}"
repo_source="\${KAKKU_REPO_SOURCE:-/opt/kakkuos/repo}"
repo_server="\${KAKKU_REPO_SERVER:-$repo_server}"
repo_embedded="\${KAKKU_REPO_EMBEDDED:-$repo_embedded}"
repo_siglevel="\${KAKKU_REPO_SIGLEVEL:-$KAKKU_REPO_SIGLEVEL}"
repo_target="\$target/opt/kakkuos/repo"
target_pacman_conf="\$target/etc/pacman.conf"

if [[ ! -d "\$target/etc" ]]; then
  echo "KakkuOS target install skipped: \$target does not look mounted." >&2
  exit 1
fi

write_repo_stanza() {
  local tmp

  tmp="\$(mktemp)"
  if [[ -f "\$target_pacman_conf" ]]; then
    awk -v repo="\$repo_name" '
      \$0 == "[" repo "]" { skip = 1; next }
      skip && \$0 ~ /^\\[/ { skip = 0 }
      !skip { print }
    ' "\$target_pacman_conf" > "\$tmp"
  fi

  cat >> "\$tmp" <<REPO

[\$repo_name]
SigLevel = \$repo_siglevel
Server = \$repo_server
REPO

  install -Dm644 "\$tmp" "\$target_pacman_conf"
  rm -f "\$tmp"
}

if [[ "\$repo_embedded" == "1" ]]; then
  if [[ ! -d "\$repo_source" ]]; then
    echo "Missing embedded KakkuOS package repo: \$repo_source" >&2
    exit 1
  fi

  mkdir -p "\$repo_target"
  rsync -a --delete "\$repo_source/" "\$repo_target/"
fi

write_repo_stanza

if [[ "\${KAKKU_SKIP_TARGET_CHROOT:-0}" == "1" ]]; then
  echo "KakkuOS target chroot install skipped."
  exit 0
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
  local repo_server

  repo_server="$(kakku_repo_server)"

  if (( skip_local_repo )) && ! using_hosted_repo; then
    echo "Skipping local KakkuOS package repo injection."
    return
  fi

  if using_hosted_repo; then
    rm -rf "$repo_target"
  else
    if [[ ! -d "$KAKKU_LOCAL_REPO_DIR" ]]; then
      echo "Missing local KakkuOS package repo: $KAKKU_LOCAL_REPO_DIR" >&2
      echo "Run packaging/build-local-repo.sh first, or rerun without --skip-local-repo." >&2
      exit 1
    fi

    local_repo_abs="$(cd "$KAKKU_LOCAL_REPO_DIR" && pwd)"

    mkdir -p "$repo_target"
    rsync -a --delete "$KAKKU_LOCAL_REPO_DIR/" "$repo_target/"
  fi

  set_repo_stanza() {
    local target_conf="$1"
    local server="$2"
    local tmp

    tmp="$(mktemp)"
    if [[ -f "$target_conf" ]]; then
      awk -v repo="$KAKKU_REPO_NAME" '
        $0 == "[" repo "]" { skip = 1; next }
        skip && $0 ~ /^\[/ { skip = 0 }
        !skip { print }
      ' "$target_conf" > "$tmp"
    fi

    cat <<EOF >> "$tmp"

[$KAKKU_REPO_NAME]
SigLevel = $KAKKU_REPO_SIGLEVEL
Server = $server
EOF

    install -Dm644 "$tmp" "$target_conf"
    rm -f "$tmp"
  }

  if using_hosted_repo; then
    set_repo_stanza "$pacman_conf" "$repo_server"
    if [[ -f "$live_pacman_conf" ]]; then
      set_repo_stanza "$live_pacman_conf" "$repo_server"
    fi
  else
    set_repo_stanza "$pacman_conf" "file://$local_repo_abs"
    if [[ -f "$live_pacman_conf" ]]; then
      set_repo_stanza "$live_pacman_conf" "file:///opt/kakkuos/repo"
    fi
  fi
}

stage_kakkuos() {
  local archiso_dir
  archiso_dir="$(find_archiso_dir)"
  local airootfs="$archiso_dir/airootfs"
  local packages_file
  packages_file="$(find_packages_file "$archiso_dir")"
  local staged_source="$airootfs/opt/kakkuos"

  mkdir -p "$staged_source"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.agents' \
    --exclude '.codex' \
    --exclude 'packaging/repo' \
    --exclude 'packaging/*/*.pkg.tar.*' \
    --exclude 'packaging/*/pkg' \
    --exclude 'packaging/*/src' \
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
  write_iso_manifest "$archiso_dir" "$airootfs" "$packages_file"

  echo "Prepared KakkuOS staging tree:"
  echo "  $KAKKU_STAGING_DIR"
  echo
  echo "Upstream CachyOS-Live-ISO cache:"
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
  echo
  echo "Build manifest:"
  echo "  $KAKKU_STAGING_DIR/$KAKKU_ISO_MANIFEST_NAME"
  if using_hosted_repo; then
    echo
    echo "Configured hosted KakkuOS package repo:"
    echo "  $(kakku_repo_server)"
  elif (( ! skip_local_repo )); then
    echo
    echo "Injected local KakkuOS package repo:"
    echo "  $airootfs/opt/kakkuos/repo"
  fi
}

build_iso() {
  cd "$KAKKU_STAGING_DIR"
  # shellcheck disable=SC2086
  sudo ./buildiso.sh -p "$CACHYOS_BUILD_PROFILE" $KAKKU_BUILDISO_ARGS
}

copy_iso_outputs() {
  local source_out="$KAKKU_STAGING_DIR/out"

  if [[ ! -d "$source_out" ]]; then
    echo "No KakkuOS staging build output directory found at $source_out."
    return
  fi

  mkdir -p "$KAKKU_ISO_OUT_DIR"
  find "$source_out" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.sha256' -o -name '*.sig' \) -exec cp -f {} "$KAKKU_ISO_OUT_DIR/" \;
  if [[ -f "$KAKKU_STAGING_DIR/$KAKKU_ISO_MANIFEST_NAME" ]]; then
    cp -f "$KAKKU_STAGING_DIR/$KAKKU_ISO_MANIFEST_NAME" "$KAKKU_ISO_OUT_DIR/"
  fi

  echo
  echo "Copied ISO artifacts to:"
  echo "  $KAKKU_ISO_OUT_DIR"
}

require_command git
require_command rsync
require_command sed
require_command awk

validate_repo_config

if (( ! prepare_only )); then
  check_full_build_requirements
fi

build_local_repo
clone_or_update_cachyos_live_iso
prepare_staging_checkout
stage_kakkuos

if (( prepare_only )); then
  echo
  echo "Prepare-only mode complete. Review the staged CachyOS tree before building."
  exit 0
fi

build_iso
copy_iso_outputs
