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
sudo pacman -S archiso base-devel mkinitcpio-archiso git pacman-contrib squashfs-tools grub rsync --needed
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
bash scripts/check-iso-package-closure.sh
scripts/iso-smoke-check.sh
```

For quick checks where the local package repo was intentionally skipped, use:

```bash
scripts/iso-smoke-check.sh --allow-missing-local-repo
```

The smoke check verifies the CLI installer entrypoints, KakkuOS package
injection, GUI installer package removal, live OS identity, boot-to-CLI target,
installer defaults, and user-facing boot branding.

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

inside the cached CachyOS-Live-ISO checkout.

The ISO output is produced by the CachyOS build system under that checkout's
`out/` directory and copied to `iso/out/` when the build completes.

## Current Limitations

This is intentionally a scaffold, not the finished release pipeline.

Still needed:

- move from the temporary file-based local package repo to a hosted KakkuOS repo
- make the CLI installer expose KakkuOS as a first-class desktop choice instead of using a wrapper-run target step
- VM-test boot, install, first boot, greetd, niri, DMS, and Zen policies

Until those are done, the ISO build is useful for integration work and live
environment experiments, not final end-user releases.
