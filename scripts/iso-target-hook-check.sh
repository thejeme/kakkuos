#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KAKKU_STAGING_DIR="${KAKKU_STAGING_DIR:-$REPO_ROOT/iso/.cache/kakku-live-iso}"
HOOK_PATH="$KAKKU_STAGING_DIR/archiso/airootfs/usr/local/bin/kakku-target-install"
REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"

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

if [[ ! -x "$HOOK_PATH" ]]; then
  fail "target hook is executable: $HOOK_PATH"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

target="$tmpdir/target"
repo_source="$tmpdir/repo-source"
hook_log="$tmpdir/hook.log"
expected_siglevel="$(awk -F'= ' '/^SigLevel = / { print $2; exit }' "$HOOK_PATH")"
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
KAKKU_REPO_SOURCE="$repo_source" \
KAKKU_REPO_SERVER="file:///opt/kakkuos/repo" \
KAKKU_REPO_EMBEDDED=1 \
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

echo "ok   target hook repo handoff"
