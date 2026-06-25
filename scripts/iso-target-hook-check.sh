#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KAKKU_STAGING_DIR="${KAKKU_STAGING_DIR:-$REPO_ROOT/iso/.cache/kakku-live-iso}"
HOOK_PATH="$KAKKU_STAGING_DIR/archiso/airootfs/usr/local/bin/kakku-target-install"
REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
MANIFEST_NAME="${KAKKU_ISO_MANIFEST_NAME:-kakku-iso-build-manifest.txt}"

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Verify the staged kakku-target-install repo handoff without chrooting.

Options:
  --staging-dir DIR   Staged KakkuOS/CachyOS-Live-ISO tree.
                      Default: iso/.cache/kakku-live-iso.
  -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging-dir)
      KAKKU_STAGING_DIR="$2"
      HOOK_PATH="$KAKKU_STAGING_DIR/archiso/airootfs/usr/local/bin/kakku-target-install"
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

fail() {
  echo "miss $*" >&2
  exit 1
}

manifest_value() {
  local file="$1"
  local key="$2"

  [[ -f "$file" ]] || return 1
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

if [[ ! -x "$HOOK_PATH" ]]; then
  fail "target hook is executable: $HOOK_PATH"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

target="$tmpdir/target"
repo_source="$tmpdir/repo-source"
hook_log="$tmpdir/hook.log"
manifest="$KAKKU_STAGING_DIR/$MANIFEST_NAME"
REPO_NAME="$(manifest_value "$manifest" kakku_repo_name 2>/dev/null || printf '%s\n' "$REPO_NAME")"
expected_siglevel="$(manifest_value "$manifest" kakku_repo_siglevel 2>/dev/null || printf 'Optional TrustAll\n')"
mkdir -p "$target/etc" "$repo_source"
printf 'fake database\n' > "$repo_source/$REPO_NAME.db"
printf 'fake package\n' > "$repo_source/kakku-desktop-0.0.0-1-any.pkg.tar.zst"

cat > "$target/etc/pacman.conf" <<EOF
[core]
Include = /etc/pacman.d/mirrorlist

[$REPO_NAME]
SigLevel = Required DatabaseOptional
Server = file:///stale/path

[extra]
Include = /etc/pacman.d/mirrorlist
EOF

KAKKU_TARGET_MOUNT="$target" \
KAKKU_REPO_NAME="$REPO_NAME" \
KAKKU_REPO_SOURCE="$repo_source" \
KAKKU_REPO_SERVER="file:///opt/kakkuos/repo" \
KAKKU_REPO_EMBEDDED=1 \
KAKKU_REPO_SIGLEVEL="$expected_siglevel" \
KAKKU_SKIP_TARGET_CHROOT=1 \
"$HOOK_PATH" >"$hook_log"

if [[ ! -f "$target/opt/kakkuos/repo/$REPO_NAME.db" ]]; then
  fail "target repo database copied"
fi

if ! grep -q '^Server = file:///opt/kakkuos/repo$' "$target/etc/pacman.conf"; then
  fail "target pacman.conf uses installed repo path"
fi

if grep -q 'file:///stale/path' "$target/etc/pacman.conf"; then
  fail "stale target repo stanza removed"
fi

repo_count="$(grep -c "^\[$REPO_NAME\]$" "$target/etc/pacman.conf")"
if [[ "$repo_count" != "1" ]]; then
  fail "target pacman.conf has one [$REPO_NAME] stanza"
fi

if [[ -z "$expected_siglevel" ]]; then
  fail "target hook declares repo SigLevel"
fi

if ! grep -Fqx "SigLevel = $expected_siglevel" "$target/etc/pacman.conf"; then
  fail "target pacman.conf uses expected repo SigLevel"
fi

hosted_target="$tmpdir/hosted-target"
hosted_server="https://repo.example.invalid/kakkuos/x86_64"
mkdir -p "$hosted_target/etc"

cat > "$hosted_target/etc/pacman.conf" <<EOF
[core]
Include = /etc/pacman.d/mirrorlist

[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file:///stale/path
EOF

KAKKU_TARGET_MOUNT="$hosted_target" \
KAKKU_REPO_NAME="$REPO_NAME" \
KAKKU_REPO_SERVER="$hosted_server" \
KAKKU_REPO_EMBEDDED=0 \
KAKKU_REPO_SIGLEVEL="$expected_siglevel" \
KAKKU_SKIP_TARGET_CHROOT=1 \
"$HOOK_PATH" >>"$hook_log"

if [[ -d "$hosted_target/opt/kakkuos/repo" ]]; then
  fail "hosted target hook does not copy embedded repo"
fi

if ! grep -Fqx "Server = $hosted_server" "$hosted_target/etc/pacman.conf"; then
  fail "hosted target pacman.conf uses hosted repo server"
fi

if grep -q 'file:///stale/path' "$hosted_target/etc/pacman.conf"; then
  fail "hosted target stale repo stanza removed"
fi

echo "ok   target hook repo handoff"
