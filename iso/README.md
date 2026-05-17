# KakkuOS ISO Build

This directory contains the first KakkuOS ISO scaffold.

KakkuOS should not maintain a separate ArchISO stack. The ISO build should use
CachyOS' supported live ISO tooling and apply KakkuOS as a profile/overlay on
top of it.

Upstream tooling:

- https://github.com/CachyOS/CachyOS-Live-ISO

## Requirements

Build on a CachyOS or Arch-based system with the CachyOS repositories available.

Install the build tools:

```bash
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub rsync --needed
```

ISO builds use loop mounts, SquashFS, pacstrap, and mkarchiso. They are not a
good fit for restricted containers.

## Prepare The CachyOS Tree

```bash
iso/build-kakku-iso.sh --prepare-only
```

This builds a local KakkuOS package repo, clones or updates CachyOS-Live-ISO
under `iso/.cache/cachyos-live-iso`, copies the current KakkuOS repository into
the live image at `/opt/kakkuos`, injects the local package repo into the live
filesystem, installs Kakku branding assets, removes the CachyOS GUI installer
packages from the live package list, and adds `kakku-desktop` plus
`cachyos-cli-installer-new`.

The live environment gets a `kakku-install` command that launches CachyOS'
terminal installer (`cachyos-installer`) through `sudo`. The live image is
also staged to boot to `multi-user.target` with a TTY installer hint, so the
installer experience is CLI-first even though the installed system receives the
KakkuOS niri desktop.

`kakku-install` starts the CachyOS CLI installer from
`/usr/share/kakku/installer`, where Kakku stages a small `settings.json`.
That settings file leaves the install interactive, but sets Kakku-friendly
defaults and registers a post-install hook. After the CLI installer finishes
the normal CachyOS install flow, that hook copies the ISO's local Kakku package
repo into the target and installs `kakku-desktop`, so the installed system gets
the KakkuOS niri/DMS desktop package and service defaults.

The script keeps backups of CachyOS files it mutates under
`archiso/.kakku-originals/` and restores them before each staging run. This
makes repeated `--prepare-only` runs deterministic while still using the
upstream checkout as the base.

The overlay also rewrites user-facing live ISO branding: live `os-release`,
hostname, release marker, boot menu labels, ISO publisher/application metadata,
MOTD, and generated ISO output naming. CachyOS repository names, mirror files,
kernel package names, and installer package names remain unchanged because they
are functional package infrastructure rather than user-facing KakkuOS branding.

If `packaging/repo` has already been built, use:

```bash
iso/build-kakku-iso.sh --prepare-only --use-existing-local-repo
```

## Smoke Check

After a prepare-only run, validate the staged tree before attempting a full ISO
build:

```bash
scripts/iso-smoke-check.sh
```

For quick checks where the local package repo was intentionally skipped, use:

```bash
scripts/iso-smoke-check.sh --allow-missing-local-repo
```

The smoke check verifies the CLI installer entrypoints, KakkuOS package
injection, GUI installer package removal, live OS identity, boot-to-CLI target,
installer defaults, and user-facing boot branding.

## Build

```bash
iso/build-kakku-iso.sh
```

The script currently delegates to:

```bash
sudo ./buildiso.sh -p desktop -v -w
```

inside the cached CachyOS-Live-ISO checkout.

The ISO output is produced by the CachyOS build system under that checkout's
`out/` directory and copied to `iso/out/` when the build completes.

## Current Limitations

This is intentionally a scaffold, not the finished release pipeline.

Still needed:

- move from the temporary file-based local package repo to a hosted KakkuOS repo
- make the CLI installer expose KakkuOS as a first-class desktop choice instead of using a post-install hook
- VM-test boot, install, first boot, greetd, niri, DMS, and Zen policies

Until those are done, the ISO build is useful for integration work and live
environment experiments, not final end-user releases.
