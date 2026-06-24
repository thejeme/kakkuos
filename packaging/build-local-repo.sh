#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
OUTPUT_DIR="${KAKKU_LOCAL_REPO_DIR:-$REPO_ROOT/packaging/repo}"
ISO_AUR_HARD_DEPS_FILE="$REPO_ROOT/packages/iso-aur-hard-deps.txt"

packages=(
  kakku-niri-settings
  kakku-desktop
)

include_aur_packages="${KAKKU_BUILD_AUR_PACKAGES:-0}"

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --output DIR       Local repository output directory.
  --repo-name NAME   Pacman repository database name. Default: kakku-local.
  --include-aur-hard-deps
                     Build AUR packages needed by Kakku hard dependencies.
  -h, --help         Show this help.

Environment:
  KAKKU_LOCAL_REPO_DIR
  KAKKU_REPO_NAME
  KAKKU_BUILD_AUR_PACKAGES
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="$2"
      shift 2
      ;;
    --include-aur-hard-deps)
      include_aur_packages=1
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

build_package() {
  local package_name="$1"
  local package_dir="$SCRIPT_DIR/$package_name"

  if [[ ! -d "$package_dir" ]]; then
    echo "Missing package directory: $package_dir" >&2
    exit 1
  fi

  (
    cd "$package_dir"
    makepkg -Cf --nodeps --noconfirm
  )
  find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -exec cp -f {} "$OUTPUT_DIR/" \;
}

build_aur_package() {
  local package_name="$1"
  local build_root="$SCRIPT_DIR/.aur-build"
  local package_dir="$build_root/$package_name"

  if [[ -d "$package_dir/.git" ]]; then
    git -C "$package_dir" fetch --depth 1 origin master
    git -C "$package_dir" reset --hard FETCH_HEAD
  else
    mkdir -p "$build_root"
    git clone --depth 1 "https://aur.archlinux.org/$package_name.git" "$package_dir"
  fi

  (
    cd "$package_dir"
    makepkg -Cfsi --noconfirm --needed
  )
  find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -exec cp -f {} "$OUTPUT_DIR/" \;
}

require_command makepkg
require_command repo-add
require_command git

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.pkg.tar.* "$OUTPUT_DIR/$REPO_NAME".db* "$OUTPUT_DIR/$REPO_NAME".files*

for package_name in "${packages[@]}"; do
  build_package "$package_name"
done

if [[ "$include_aur_packages" == "1" ]]; then
  if [[ ! -f "$ISO_AUR_HARD_DEPS_FILE" ]]; then
    echo "Missing ISO AUR hard dependency list: $ISO_AUR_HARD_DEPS_FILE" >&2
    exit 1
  fi

  while IFS= read -r package_name; do
    build_aur_package "$package_name"
  done < <(read_package_file "$ISO_AUR_HARD_DEPS_FILE")
fi

(
  cd "$OUTPUT_DIR"
  rm -f "$REPO_NAME.db" "$REPO_NAME.files"
  repo-add "$REPO_NAME.db.tar.gz" ./*.pkg.tar.*
)

echo "Local KakkuOS package repo built:"
echo "  $OUTPUT_DIR"
echo
echo "Pacman repository stanza:"
cat <<EOF
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$OUTPUT_DIR
EOF
