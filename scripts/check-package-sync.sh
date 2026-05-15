#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$REPO_DIR/packages/profiles"
EXTRAS_FILE="$REPO_DIR/packages/pacman.txt"
AUR_FILE="$REPO_DIR/packages/aur.txt"
PKGBUILD="$REPO_DIR/packaging/kakku-desktop/PKGBUILD"

read_package_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    sed -E '/^[[:space:]]*#/d;/^[[:space:]]*$/d;s/[[:space:]]+$//' "$file"
  fi
}

read_profile_packages() {
  local file

  for file in "$PROFILES_DIR"/*.txt; do
    [[ -f "$file" ]] || continue
    read_package_file "$file"
  done

  read_package_file "$EXTRAS_FILE"
}

read_pkgbuild_depends() {
  awk '
    $0 ~ /^depends=\(/ { in_depends = 1; next }
    in_depends && $0 ~ /^\)/ { in_depends = 0; next }
    in_depends {
      gsub(/'\''/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if ($0 != "") print $0
    }
  ' "$PKGBUILD"
}

sort_unique() {
  sort -u
}

comm_missing_left() {
  local left="$1"
  local right="$2"

  comm -23 "$left" "$right"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

profiles="$tmpdir/profiles"
depends="$tmpdir/depends"
aur="$tmpdir/aur"
missing_from_depends="$tmpdir/missing-from-depends"
extra_in_depends="$tmpdir/extra-in-depends"
aur_in_profiles="$tmpdir/aur-in-profiles"

read_profile_packages | sort_unique > "$profiles"
read_pkgbuild_depends | grep -v '^kakku-hyprland-settings$' | sort_unique > "$depends"
read_package_file "$AUR_FILE" | sort_unique > "$aur"

comm_missing_left "$profiles" "$depends" > "$missing_from_depends"
comm_missing_left "$depends" "$profiles" > "$extra_in_depends"
comm -12 "$profiles" "$aur" > "$aur_in_profiles"

failed=0

if [[ -s "$missing_from_depends" ]]; then
  failed=1
  echo "Packages in profiles but missing from packaging/kakku-desktop/PKGBUILD depends:"
  sed 's/^/  - /' "$missing_from_depends"
fi

if [[ -s "$extra_in_depends" ]]; then
  failed=1
  echo "Packages in packaging/kakku-desktop/PKGBUILD depends but missing from profiles:"
  sed 's/^/  - /' "$extra_in_depends"
fi

if [[ -s "$aur_in_profiles" ]]; then
  failed=1
  echo "AUR packages must stay out of pacman profiles:"
  sed 's/^/  - /' "$aur_in_profiles"
fi

if (( failed )); then
  exit 1
fi

echo "Package profiles and kakku-desktop dependencies are in sync."

