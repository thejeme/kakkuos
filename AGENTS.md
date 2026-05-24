# KakkuOS Agent Context

This repository builds and documents KakkuOS, a layered Linux desktop distribution on top of CachyOS. Treat CachyOS as the base system provider: kernel, repositories, hardware enablement, gaming stack, and performance tuning come from CachyOS. KakkuOS adds the desktop experience, defaults, branding, package selection, helper commands, and install/ISO overlays.

AI tools should use this file to understand the system and help both developers and normal users. For non-developer support and practical system tweaking, prefer `TWEAKING.md`.

## System Identity

- Base: CachyOS / Arch Linux ecosystem.
- Desktop session: niri Wayland compositor with DankMaterialShell.
- Display compatibility: Wayland first, Xwayland Satellite for X11 apps.
- Login: greetd with the DMS greeter.
- Terminal and shell: Ghostty, fish, Starship.
- Browsers: Zen Browser as the default, Chrome as a secondary browser.
- Files and CLI navigation: Dolphin and Yazi.
- Editors: VS Code and Neovim.
- Audio: PipeWire, PipeWire Pulse, WirePlumber.
- Gaming: CachyOS gaming meta packages, Steam stack through CachyOS packages.

KakkuOS should feel like a curated CachyOS desktop, not a separate base distribution. Avoid duplicating lower-level OS responsibilities that CachyOS already handles well.

## Normal User Support

Most people asking for KakkuOS help are likely trying to tweak a running desktop, not develop the distribution. Start from user-level settings and explain changes in plain language.

Common support areas:

- DMS bar, launcher, lock screen, notifications, power menu, wallpaper, OSDs, and theme behavior.
- niri keybindings, startup commands, workspaces, screenshots, window rules, and monitor behavior.
- idle behavior through `swayidle`, `niri-screensaver-ctl`, and DMS lock commands.
- default apps through `kakku defaults`.
- browser policies and theme hooks through `kakku browser-theme` and `kakku-browser-policies`.
- health checks through `kakku doctor`, `kakku doctor --fix`, and `kakku services`.

Prefer these safe commands when helping users inspect or apply changes:

```bash
kakku doctor
kakku services
kakku keybinds
niri validate -c ~/.config/niri/config.kdl
niri msg action load-config-file
niri msg outputs
dms doctor
dms restart
dms randr
```

Be careful with:

- editing generated files under `~/.config/niri/dms/`;
- overwriting `~/.config/DankMaterialShell/settings.json`;
- suggesting package rebuilds, ISO builds, or PKGBUILD edits to non-developers;
- destructive shell commands;
- changing system services before checking whether a user-level restart solves the issue.

When a normal user wants a tweak, give exact files and commands, explain whether logout/reboot is needed, and keep the change reversible.

## Repository Map

- `TWEAKING.md`: practical context for helping normal users customize KakkuOS.
- `install.sh`: installs KakkuOS on top of an existing CachyOS system.
- `bin/`: installed `kakku*` user/admin helper commands.
- `dotfiles/`: user-facing config defaults copied into `~/.config` or packaged into `/etc/skel`.
- `system/`: system defaults, DMS defaults, greeter config, browser policies, environment defaults, and OS branding.
- `packages/profiles/`: pacman package profiles split by purpose.
- `packages/aur.txt`: required/default AUR packages.
- `packaging/`: local Arch PKGBUILDs for Kakku package sets.
- `iso/`: CachyOS-Live-ISO overlay/scaffold for KakkuOS ISO work.
- `scripts/`: repository validation and ISO smoke checks.
- `branding/` and `backgrounds/`: installed visual assets.

Installed shared assets live under `/usr/share/kakku/` and backgrounds under `/usr/share/backgrounds/kakku/`.

## Install Model

`install.sh` is designed to run as the target desktop user, not under `sudo`. It asks for sudo only for system changes. It is non-interactive by default through `KAKKU_NONINTERACTIVE=1`; set `KAKKU_NONINTERACTIVE=0` for interactive package manager behavior.

The installer:

- installs pacman packages from all `packages/profiles/*.txt` plus `packages/pacman.txt`;
- installs AUR packages from `packages/aur.txt` with `paru` or `yay`;
- removes CachyOS desktop defaults that KakkuOS replaces, such as CachyOS hello/wallpapers/shell config packages;
- copies Kakku-owned dotfiles into the current user config;
- installs branding, backgrounds, DMS defaults, browser policy defaults, helper commands, and niri portal config;
- sets fish as the user's login shell;
- enables greetd and core services when available;
- enables DMS and dsearch user services when their unit files exist;
- applies KakkuOS `/usr/lib/os-release` branding.

Do not make the installer depend on running as root. Keep user-owned config writes separate from privileged system writes.

## Desktop Defaults

The main niri config is `dotfiles/niri/config.kdl`. It integrates DMS launcher, clipboard, settings, power menu, notifications, media keys, screenshot bindings, wallpaper tools, and niri window/workspace controls.

Important conventions:

- `Mod` is Super in the shipped niri config.
- `Mod+Space` opens the DMS spotlight/app launcher.
- `Mod+T` opens Ghostty.
- `Mod+E` opens Dolphin.
- `Mod+B` opens Zen Browser.
- `Mod+Shift+B` opens Chrome.
- `Mod+Shift+L` locks through DMS.
- `Print` and related bindings use niri screenshots.
- Media and brightness keys call DMS IPC helpers.
- Idle behavior is handled through `swayidle`, `niri-screensaver-ctl`, and DMS lock commands.

DMS defaults live in `system/dms/settings.defaults.json`; the Kakku DMS theme lives in `system/dms/themes/kakku/theme.json`. User-edited DMS settings should remain authoritative after first boot unless a repair/defaults command explicitly restores missing config.

## Package Model

Package profile files are the source of truth for user-visible package groups:

- `core.txt`: base tools, CachyOS helpers, firewall, networking, Bluetooth, Docker, Tailscale.
- `desktop.txt`: niri, DMS, portals, audio, fonts, desktop apps, greetd.
- `cli.txt`: shell and terminal tools.
- `development.txt`: developer tooling, including GitHub CLI, Node, Codex, Neovim, Lazygit/Lazydocker.
- `gaming.txt`: CachyOS gaming package groups.
- `media.txt`: media, office, and creative applications.

Keep AUR-only packages out of `packages/profiles/*.txt`; put them in `packages/aur.txt`. When package lists change, update `packaging/kakku-desktop/PKGBUILD` and run:

```bash
scripts/check-package-sync.sh
```

## Packaging Model

`packaging/kakku-niri-settings` packages Kakku desktop defaults into `/etc/skel`, `/usr/share/kakku`, `/usr/share/backgrounds/kakku`, `/usr/bin/kakku*`, DMS defaults, greetd config, portal config, environment defaults, and branding.

`packaging/kakku-desktop` is a meta package depending on the full default desktop package set and `kakku-niri-settings`.

Prefer changing package lists and package metadata together. Do not hard-code installed-file assumptions in only one path when both direct install and package install need the same behavior.

## ISO Model

The ISO work under `iso/` is a scaffold around CachyOS-Live-ISO. KakkuOS should not maintain a separate ArchISO stack. The overlay injects this repository, local Kakku packages, CLI installer defaults, branding, boot labels, and a `kakku-install` command while keeping CachyOS repository/kernel infrastructure intact.

Useful commands:

```bash
iso/build-kakku-iso.sh --prepare-only
scripts/iso-smoke-check.sh
```

Full ISO builds require loop mounts, SquashFS, pacstrap, mkarchiso, and root privileges, so they are not suitable for restricted containers.

## Validation

Prefer these checks after relevant changes:

```bash
scripts/check-package-sync.sh
niri validate -c dotfiles/niri/config.kdl
shellcheck install.sh bin/kakku bin/kakku-* scripts/*.sh iso/*.sh
```

Run only the checks that apply to the change and are available in the environment. If a command is missing, say so instead of rewriting code around the missing tool.

## Engineering Guidelines

- Keep changes aligned with the layered model: CachyOS base, KakkuOS desktop/defaults layer.
- Preserve user config ownership. Installer defaults can seed config; repair commands should avoid overwriting user-edited files unless clearly intended.
- Keep package profile files simple: one package per line, comments allowed, no AUR packages in pacman profiles.
- Keep scripts POSIX-adjacent Bash with `set -euo pipefail` where already used.
- Prefer idempotent install and repair behavior.
- Avoid adding new runtime dependencies unless they belong in a package profile and packaging metadata.
- Keep generated DMS/niri files marked as generated if DMS owns them.
- When changing keybindings, update both `dotfiles/niri/config.kdl` and the `kakku keybinds` output in `bin/kakku`.
