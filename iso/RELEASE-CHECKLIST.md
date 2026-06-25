# KakkuOS ISO Release Checklist

Use this checklist for any ISO intended for testers or users. A prepare-only
staged tree is not enough for release.

## 1. Build Host

- [ ] Build host is CachyOS or Arch-based with CachyOS repositories available.
- [ ] Required tools installed:

```bash
sudo pacman -S archiso base-devel mkinitcpio-archiso git pacman-contrib squashfs-tools grub rsync arch-install-scripts --needed
```

- [ ] Optional VM test tools installed:

```bash
sudo pacman -S qemu-desktop edk2-ovmf swtpm --needed
```

- [ ] Build-host preflight passes:

```bash
scripts/iso-host-preflight.sh --require-vm-tools --require-uefi
```

## 2. Staging

- [ ] Build from a reviewed KakkuOS git commit.
- [ ] Package profiles and `kakku-desktop` dependencies are in sync:

```bash
scripts/check-package-sync.sh
```

- [ ] ISO hard dependencies resolve from pacman repos or the bundled ISO AUR
      manifest:

```bash
bash scripts/check-iso-package-closure.sh
```

- [ ] Prepare the staging tree:

```bash
iso/build-kakku-iso.sh --prepare-only
```

- [ ] For release candidates, prefer a hosted signed KakkuOS repo:

```bash
iso/build-kakku-iso.sh --prepare-only \
  --repo-server https://REPO_HOST/kakkuos/x86_64 \
  --repo-siglevel "Required DatabaseOptional"
```

Expected manifest field: `kakku_repo_mode=hosted`.

- [ ] Smoke check passes with zero failures:

```bash
scripts/iso-smoke-check.sh
```

- [ ] Generated target install hook dry-run passes:

```bash
scripts/iso-target-hook-check.sh
```

- [ ] Build manifest exists and records clean source state:

```bash
grep -E '^(kakku_commit|kakku_worktree_dirty|cachyos_live_iso_commit)=' \
  iso/.cache/kakku-live-iso/kakku-iso-build-manifest.txt
```

Expected `kakku_worktree_dirty=no`.

- [ ] Upstream CachyOS cache is clean:

```bash
git -C iso/.cache/cachyos-live-iso status --short
```

Expected output: empty.

## 3. Full ISO Build

- [ ] Build the ISO:

```bash
iso/build-kakku-iso.sh
```

- [ ] Release audit passes:

```bash
scripts/iso-release-check.sh --require-hosted-repo --check-host
```

For an embedded-repo test ISO, omit `--require-hosted-repo` and document that
choice in the release notes.

- [ ] Record produced artifacts:

```text
ISO:
SHA256:
Signature:
Package list:
Manifest:
Build host:
KakkuOS commit:
CachyOS-Live-ISO ref:
```

## 4. VM Live Boot

- [ ] Boot the ISO in BIOS mode:

```bash
scripts/iso-vm-boot.sh --bios
```

- [ ] Boot the ISO in UEFI mode:

```bash
scripts/iso-vm-boot.sh --uefi
```

- [ ] Boot menu labels say KakkuOS.
- [ ] Live environment reaches TTY auto-login.
- [ ] Live hostname is `kakkuos`.
- [ ] `kakku-install` is on `PATH`.
- [ ] `kakku-install --help` or installer startup reaches the CachyOS CLI installer.
- [ ] `/opt/kakkuos/repo/kakku-local.db` exists in the live system.
      This is only required for embedded-repo test ISOs.

Manual QEMU fallback:

```bash
qemu-system-x86_64 \
  -m 4096 \
  -enable-kvm \
  -cdrom iso/out/NAME_OF_ISO.iso \
  -boot d
```

## 5. VM Install

- [ ] Install to a blank virtual disk using `kakku-install`.
- [ ] Use the default Kakku settings unless testing a variant:
  `linux-cachyos`, `niri`, `fish`, `limine`, `btrfs`.
- [ ] Confirm the post-install hook reports:

```text
KakkuOS target packages and services applied.
```

- [ ] Before reboot, confirm target repo handoff:

```bash
grep -A2 '^\[kakku-local\]$' /mnt/etc/pacman.conf
test -f /mnt/opt/kakkuos/repo/kakku-local.db
arch-chroot /mnt pacman -Q kakku-desktop kakku-niri-settings
```

## 6. First Boot

- [ ] Installed system boots without the ISO.
- [ ] `/etc/os-release` reports KakkuOS.
- [ ] `greetd.service` is enabled.
- [ ] `sddm.service` and `ly.service` are not enabled.
- [ ] Login reaches the niri session with DankMaterialShell.
- [ ] `kakku doctor` passes or only reports documented non-release blockers.
- [ ] `kakku services` shows expected core services.
- [ ] `kakku keybinds` matches shipped niri defaults.
- [ ] Zen Browser launches and default browser policies apply.
- [ ] DMS launcher, bar, power menu, lock, notifications, and wallpaper work.

## 7. Publish

- [ ] ISO filename, checksum, and signature are copied to the release location.
- [ ] Release notes mention the CachyOS base and Kakku desktop layer.
- [ ] Known limitations are listed, especially if using the embedded local repo.
- [ ] VM evidence is attached or linked before public announcement.
