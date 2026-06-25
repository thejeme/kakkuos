# KakkuOS ISO Status

Last updated: 2026-06-25

## Current State

The ISO workflow is a CachyOS-Live-ISO overlay, not a separate ArchISO stack.
That is the right direction for KakkuOS.

The current local workflow can:

- clone/update CachyOS-Live-ISO into a clean upstream cache;
- sync a separate mutable Kakku staging tree;
- build and inject local KakkuOS packages for embedded-repo test ISOs;
- optionally configure a hosted KakkuOS pacman repo with `--repo-server`;
- stage KakkuOS source, branding, live identity, boot labels, installer config,
  and helper commands into the live image;
- remove CachyOS GUI installer packages and use the CachyOS CLI installer;
- generate a target post-install hook that installs `kakku-desktop` and enables
  Kakku service defaults;
- write a build manifest with Kakku/CachyOS commits, repo mode, repo server,
  and dirty-worktree state;
- check that ISO hard dependencies are either pacman-resolvable or listed in
  the bundled ISO AUR manifest;
- run staged-tree smoke checks, target-hook dry-run checks, host preflight
  checks, and release audits.

## Current Workspace Validation

After the 2026-06-25 local changes, these checks passed in this workspace:

```bash
bash -n iso/build-kakku-iso.sh scripts/iso-smoke-check.sh scripts/iso-target-hook-check.sh scripts/iso-release-check.sh scripts/iso-vm-boot.sh scripts/iso-host-preflight.sh packaging/build-local-repo.sh scripts/check-iso-package-closure.sh
scripts/check-package-sync.sh
```

The ISO package closure check also passed its local manifest checks in this
workspace, but skipped pacman repository resolution because pacman is not
installed here:

```bash
bash scripts/check-iso-package-closure.sh
```

The prepare-only, smoke, target-hook, and release-audit commands below were
validated before the latest local changes and must be rerun on a CachyOS/Arch
host or Linux environment after these edits:

```bash
iso/build-kakku-iso.sh --prepare-only
bash scripts/check-iso-package-closure.sh
scripts/iso-smoke-check.sh
scripts/iso-target-hook-check.sh
scripts/iso-release-check.sh --allow-missing-iso --allow-missing-vm-tools --allow-dirty-source
```

Hosted-repo staging was also validated in `/tmp/kakku-hosted-live-iso` with:

```bash
iso/build-kakku-iso.sh --prepare-only \
  --repo-server https://repo.example.invalid/kakkuos/x86_64 \
  --repo-siglevel "Required DatabaseOptional"
scripts/iso-smoke-check.sh --dir /tmp/kakku-hosted-live-iso
scripts/iso-target-hook-check.sh --staging-dir /tmp/kakku-hosted-live-iso
scripts/iso-release-check.sh --staging-dir /tmp/kakku-hosted-live-iso \
  --allow-missing-iso --allow-missing-vm-tools --allow-dirty-source \
  --require-hosted-repo
```

The upstream CachyOS cache was clean after staging.

The host preflight script was also run in this workspace and correctly failed
because this machine is missing full-build and VM-test requirements:

- `mkarchiso`;
- `mksquashfs`;
- `pacstrap`;
- QEMU tools;
- OVMF firmware;
- usable loop/KVM readiness for the release workflow.

## Not Yet Proven

The ISO workflow is not complete for release yet because these gates have not
been proven:

- full ISO build on a CachyOS/Arch host with root-capable ISO tooling;
- package closure check on a CachyOS/Arch host with pacman sync databases;
- produced ISO, checksum, and signature artifacts under `iso/out`;
- BIOS and UEFI VM live boot;
- CLI installer flow through `kakku-install`;
- target install and first boot without the ISO;
- greetd, niri, DankMaterialShell, default apps, browser policies, and Kakku
  helper behavior on the installed system;
- real hosted and signed KakkuOS package repo for release candidates.

## Next Steps

1. Run the build-host preflight on a CachyOS/Arch build host:

```bash
scripts/iso-host-preflight.sh --require-vm-tools --require-uefi
```

2. Run a full ISO build on that host:

```bash
iso/build-kakku-iso.sh
```

3. Run release audit on the build host:

```bash
scripts/iso-release-check.sh --require-hosted-repo --check-host
```

For embedded-repo test ISOs, omit `--require-hosted-repo` and document that the
ISO depends on its bundled `/opt/kakkuos/repo`.

4. VM-test both firmware paths:

```bash
scripts/iso-vm-boot.sh --bios
scripts/iso-vm-boot.sh --uefi
```

5. Complete a VM install with `kakku-install`, reboot into the installed system,
   and verify the checklist in `iso/RELEASE-CHECKLIST.md`.

6. For release-quality ISOs, publish/sign a hosted KakkuOS pacman repo and build
   with `--repo-server` plus a strict `--repo-siglevel`.
