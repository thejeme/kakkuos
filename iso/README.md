# KakkuOS ISO Build

This directory contains the KakkuOS ISO scaffold.

KakkuOS should not maintain a separate ArchISO stack. The ISO build should use
CachyOS' supported live ISO tooling and apply KakkuOS as a profile/overlay on
top of it.

Upstream tooling:

- https://github.com/CachyOS/CachyOS-Live-ISO

## Requirements

Build on a CachyOS or Arch-based system with the CachyOS repositories available.

Install the build tools:

```bash
sudo pacman -S archiso base-devel mkinitcpio-archiso git pacman-contrib squashfs-tools grub rsync arch-install-scripts --needed
```

ISO builds use loop mounts, SquashFS, pacstrap, and mkarchiso. They are not a
good fit for restricted containers.

## Installer Strategy

Yes, a CachyOS-based CLI installer ISO is the right direction for KakkuOS.
KakkuOS depends on CachyOS for the kernel, repositories, hardware enablement,
gaming stack, and performance defaults, so the ISO should keep CachyOS'
installer and live build machinery responsible for base-system installation.

KakkuOS should add only the desktop layer:

- live ISO branding and boot hints
- `kakku-install` as the user-facing installer command
- KakkuOS packages and package repository configuration
- niri/DankMaterialShell defaults, helpers, browser policies, and branding
- post-install service/default setup for the installed target

Do not fork ArchISO or replace the CachyOS base installer unless the CachyOS CLI
installer cannot support the required hook points. A small overlay is easier to
keep compatible with CachyOS updates.

## Prepare The CachyOS Tree

```bash
iso/build-kakku-iso.sh --prepare-only
```

This builds a local KakkuOS package repo, including AUR packages listed in
`packages/iso-aur-hard-deps.txt` because Kakku packages need them as hard
dependencies. Those bundled AUR packages are built with `makepkg -i`, so they
can be installed on the build host while the local repo is assembled and
transitive AUR dependencies can be resolved by later package builds. The script
then clones or updates CachyOS-Live-ISO under
`iso/.cache/cachyos-live-iso`, copies the current KakkuOS repository into the
live image at `/opt/kakkuos`, injects the local package repo into the live
filesystem, installs Kakku branding assets, removes the CachyOS GUI installer
packages from the live package list, and adds `kakku-desktop` plus
`cachyos-cli-installer-new`.

There are two local repo paths to keep separate:

- the CachyOS build profile `pacman.conf` uses the build host's
  `KAKKU_LOCAL_REPO_DIR`, so `mkarchiso` can resolve `kakku-desktop`
- the live image and installed target use `file:///opt/kakkuos/repo`, which is
  copied into the ISO and then into the installed system

The live environment gets a `kakku-install` command that launches CachyOS'
terminal installer (`cachyos-installer` from `cachyos-cli-installer-new`)
through `sudo`, with a legacy `install_cachyos` fallback if the installer
package is swapped. The live image is also staged to boot to
`multi-user.target` with a TTY installer hint, so the installer experience is
CLI-first even though the installed system receives the KakkuOS niri desktop.

`kakku-install` starts the CachyOS CLI installer from
`/usr/share/kakku/installer`, where Kakku stages a small `settings.json` for
installer defaults when supported. The wrapper does not rely on that file for
KakkuOS setup: after the CachyOS installer returns, it checks for an installed
target at `/mnt` or `KAKKU_TARGET_MOUNT` and runs `kakku-target-install`.
That target step copies the ISO's local Kakku package repo into the target,
adds the target-local pacman repo, and installs `kakku-desktop`, so the
installed system gets the KakkuOS niri/DMS desktop package and service defaults.

The upstream CachyOS checkout is treated as a clean cache. Kakku mutations are
applied to the separate staging tree on every run, so repeated `--prepare-only`
runs stay deterministic without modifying the cached upstream checkout.

The overlay also rewrites user-facing live ISO branding: live `os-release`,
hostname, release marker, boot menu labels, ISO publisher/application metadata,
MOTD, and generated ISO output naming. CachyOS repository names, mirror files,
kernel package names, and installer package names remain unchanged because they
are functional package infrastructure rather than user-facing KakkuOS branding.

Each staging run writes `kakku-iso-build-manifest.txt` into the staging tree and
the live image at `/usr/share/kakku/`. The manifest records the KakkuOS commit,
worktree dirty state, CachyOS-Live-ISO commit, profile, installer package, and
embedded local repo package files.

If `packaging/repo` has already been built, use:

```bash
iso/build-kakku-iso.sh --prepare-only --use-existing-local-repo
```

To use a hosted KakkuOS pacman repo instead of embedding `packaging/repo`, pass
the repo server URL:

```bash
iso/build-kakku-iso.sh --prepare-only \
  --repo-server https://repo.example.invalid/kakkuos/x86_64 \
  --repo-siglevel "Required DatabaseOptional"
```

Hosted repo mode writes the same repo stanza into the live and target
`pacman.conf` files, records `kakku_repo_mode=hosted` in the manifest, and
skips embedding `/opt/kakkuos/repo`. The hosted repo must already contain
`kakku-desktop` and `kakku-niri-settings` before a full ISO build.

## Smoke Check

After a prepare-only run, validate the staged tree before attempting a full ISO
build:

```bash
bash scripts/check-iso-package-closure.sh
scripts/iso-smoke-check.sh
scripts/iso-target-hook-check.sh
```

For quick checks where the local package repo was intentionally skipped, use:

```bash
scripts/iso-smoke-check.sh --allow-missing-local-repo
```

The smoke check verifies the CLI installer entrypoints, KakkuOS package
injection, GUI installer package removal, live OS identity, boot-to-CLI target,
installer defaults, and user-facing boot branding. The target hook check runs
the generated `kakku-target-install` script against a fake mounted target and
verifies that it copies the local package repo and rewrites target
`pacman.conf` before the chrooted install step.

`--skip-local-repo` is only for prepare-only inspection. A full ISO build needs
`kakku-desktop` and `kakku-niri-settings` available to pacman, either by letting
`iso/build-kakku-iso.sh` build and inject `packaging/repo` or by passing
`--use-existing-local-repo` after building that repo yourself. A full build can
also use `--repo-server` when those packages are available from a hosted KakkuOS
repo.

## Release Audit

For release candidates, use the checklist in `iso/RELEASE-CHECKLIST.md`.
After a full ISO build, run:

```bash
scripts/iso-release-check.sh --require-hosted-repo --check-host
```

For pre-build local checks where no ISO artifact exists yet, use:

```bash
scripts/iso-release-check.sh --allow-missing-iso
```

For early embedded-repo test ISOs, omit `--require-hosted-repo` and document
that the ISO depends on its bundled `/opt/kakkuos/repo` package database.

On machines that cannot run VM tests, add `--allow-missing-vm-tools`. Do not use
that flag for a real release candidate.

For local development audits from an uncommitted worktree, add
`--allow-dirty-source`. Do not use that flag for a real release candidate.

For manual VM validation after a build, use:

```bash
scripts/iso-vm-boot.sh --bios
scripts/iso-vm-boot.sh --uefi
```

The helper boots the newest ISO under `iso/out/` by default and creates a
reusable test disk at `iso/.cache/kakku-vm.qcow2`.

## Release Gates

Before publishing an ISO for normal users, verify all of these on a real
CachyOS/Arch build host and in a VM:

- `iso/build-kakku-iso.sh --prepare-only`
- `bash scripts/check-iso-package-closure.sh`
- `scripts/iso-smoke-check.sh`
- `iso/build-kakku-iso.sh`
- boot the produced ISO in UEFI and BIOS/legacy mode if supported by upstream
- run `kakku-install` through an interactive install
- confirm the KakkuOS target step runs after install and installs `kakku-desktop`
- first boot reaches greetd, starts niri with DMS, and loads Kakku branding
- `kakku doctor` passes or reports only documented non-fatal warnings
- Zen Browser policies, default apps, audio, networking, Bluetooth, and GPU
  packages behave as expected
- test at least one clean online install and one install using only the local
  ISO-injected KakkuOS repo

Treat a passing ISO build as insufficient by itself. The release artifact is
only user-ready after boot, install, first-login, and rollback/reinstall paths
have been tested.

## Build

```bash
iso/build-kakku-iso.sh
```

The script currently delegates to:

```bash
sudo ./buildiso.sh -p desktop -v -w
```

inside the Kakku staging tree at `iso/.cache/kakku-live-iso`. The upstream
checkout at `iso/.cache/cachyos-live-iso` remains a clean source cache.

Before a full build starts, the Kakku wrapper checks for the external build
commands it cannot provide itself: `sudo`, `mkarchiso`, `mksquashfs`, and
`pacstrap`.

The ISO output is produced by the CachyOS build system under the staging tree's
`out/` directory and copied to `iso/out/` when the build completes.

## Current Limitations

The ISO path is currently good enough for staged-tree integration work:

- it clones or updates CachyOS-Live-ISO instead of maintaining a separate
  ArchISO tree;
- it applies Kakku changes in a separate staging/build tree instead of mutating
  the upstream cache;
- it builds/injects the local KakkuOS package repo;
- it can alternatively point the live and installed systems at a hosted KakkuOS
  pacman repo;
- it stages this repository into the live image;
- it removes the CachyOS GUI installer packages and adds the CachyOS CLI
  installer;
- it brands the live identity, boot labels, hostname, MOTD, and output naming;
- it boots the live image to a CLI target with a `kakku-install` hint;
- it provides a target post-install hook that copies the local repo into the
  installed system, adds that repo to target `pacman.conf`, installs
  `kakku-desktop`, and enables Kakku service defaults;
- it has a smoke check for the staged tree.

It is not yet a finished release pipeline.

Still needed:

- move from the temporary file-based local package repo to a hosted KakkuOS repo
- make the CLI installer expose KakkuOS as a first-class desktop choice instead of using a wrapper-run target step
- VM-test boot, install, first boot, greetd, niri, DMS, and Zen policies

Until those are done, the ISO build is useful for integration work and live
environment experiments, not final end-user releases.
