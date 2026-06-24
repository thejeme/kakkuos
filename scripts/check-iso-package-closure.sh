#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUR_FILE="$REPO_DIR/packages/aur.txt"
ISO_AUR_HARD_DEPS_FILE="$REPO_DIR/packages/iso-aur-hard-deps.txt"

local_packages=(
  kakku-niri-settings
  kakku-desktop
)

pkgbuilds=(
  "$REPO_DIR/packaging/kakku-niri-settings/PKGBUILD"
  "$REPO_DIR/packaging/kakku-desktop/PKGBUILD"
)

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

read_pkgbuild_depends() {
  local file="$1"

  awk '
    $0 ~ /^depends=\(/ { in_depends = 1; next }
    in_depends && $0 ~ /^\)/ { in_depends = 0; next }
    in_depends {
      gsub(/'\''/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if ($0 != "") print $0
    }
  ' "$file"
}

sort_unique() {
  sort -u
}

contains_line() {
  local needle="$1"
  local file="$2"

  grep -Fxq "$needle" "$file"
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

depends="$tmpdir/depends"
aur="$tmpdir/aur"
bundled_aur="$tmpdir/bundled-aur"
hard_aur_deps="$tmpdir/hard-aur-deps"
missing_bundled_aur="$tmpdir/missing-bundled-aur"
bundled_missing_from_aur="$tmpdir/bundled-missing-from-aur"
repo_checked_deps="$tmpdir/repo-checked-deps"

if [[ ! -f "$ISO_AUR_HARD_DEPS_FILE" ]]; then
  echo "Missing ISO AUR hard dependency list: $ISO_AUR_HARD_DEPS_FILE" >&2
  exit 1
fi

for pkgbuild in "${pkgbuilds[@]}"; do
  read_pkgbuild_depends "$pkgbuild"
done | sort_unique > "$depends"

read_package_file "$AUR_FILE" | sort_unique > "$aur"
read_package_file "$ISO_AUR_HARD_DEPS_FILE" | sort_unique > "$bundled_aur"

if [[ ! -s "$bundled_aur" ]]; then
  echo "ISO AUR hard dependency list is empty: $ISO_AUR_HARD_DEPS_FILE" >&2
  exit 1
fi

comm -12 "$depends" "$aur" > "$hard_aur_deps"
comm -23 "$hard_aur_deps" "$bundled_aur" > "$missing_bundled_aur"
comm -23 "$bundled_aur" "$aur" > "$bundled_missing_from_aur"

failed=0

if [[ -s "$missing_bundled_aur" ]]; then
  failed=1
  echo "AUR packages used as hard dependencies must be bundled into the ISO local repo:"
  sed 's/^/  - /' "$missing_bundled_aur"
fi

if [[ -s "$bundled_missing_from_aur" ]]; then
  failed=1
  echo "Bundled ISO AUR packages must also be listed in packages/aur.txt:"
  sed 's/^/  - /' "$bundled_missing_from_aur"
fi

if command -v pacman >/dev/null 2>&1; then
  while IFS= read -r package_name; do
    skip=0

    for local_package in "${local_packages[@]}"; do
      if [[ "$package_name" == "$local_package" ]]; then
        skip=1
        break
      fi
    done

    if (( skip )) || contains_line "$package_name" "$bundled_aur"; then
      continue
    fi

    printf '%s\n' "$package_name"
  done < "$depends" > "$repo_checked_deps"

  while IFS= read -r package_name; do
    if ! pacman -Sp --noconfirm "$package_name" >/dev/null 2>&1; then
      failed=1
      echo "Package is not resolvable from enabled pacman repos: $package_name"
    fi
  done < "$repo_checked_deps"
else
  echo "Skipping pacman repository resolution check: pacman is not installed."
fi

if (( failed )); then
  exit 1
fi

echo "ISO package closure checks passed."
