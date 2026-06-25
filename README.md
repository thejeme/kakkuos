# KakkuOS

KakkuOS is a Layered Linux desktop built on CachyOS, niri, DankMaterialShell, Ghostty, fish, and a focused set of desktop defaults. It keeps the lower CachyOS system layer practical and fast, then adds a Kakku-owned user experience: session config, shell defaults, applications, branding, keybinds, default apps, and helper commands.

## Stack

- **Desktop**: niri + DankMaterialShell
- **Display**: Wayland + Xwayland Satellite
- **Terminal**: Ghostty
- **Shell**: fish with Starship
- **Browsers**: Zen Browser and Chrome
- **Files**: Dolphin and Yazi
- **Editor**: VS Code and Neovim
- **Audio**: PipeWire + WirePlumber
- **Gaming**: CachyOS gaming meta packages

CachyOS provides the kernel, repositories, hardware enablement, gaming stack, and performance tuning layer.

## Install

KakkuOS is designed to be installed on top of a fresh [CachyOS](https://cachyos.org/) base system. CachyOS provides the kernel, repositories, hardware enablement, and performance tuning that KakkuOS builds upon. Install CachyOS first (a minimal or desktop install both work), then run the installer from a full checkout:

```bash
git clone https://github.com/TheJeme/kakkuos
cd kakkuos
./install.sh
```

Run `./install.sh` as the target desktop user, not through `sudo`; the script asks for sudo only for system changes.

The installer installs package profiles, copies Kakku-owned dotfiles, sets fish as the login shell, applies branding, sets default apps, configures greetd with the DMS greeter, removes Plymouth, applies Limine timeout defaults, and enables common services. It assumes CachyOS repositories and required AUR packages are available on the system.

## ISO Work

KakkuOS also has an experimental CachyOS-Live-ISO overlay in `iso/`. It stages a CLI-first live image with `kakku-install`, delegates base installation to the CachyOS CLI installer, then applies the KakkuOS desktop package and defaults to
the installed target.

See `iso/README.md` for build requirements, smoke checks, release gates, and the
current limitations before treating an ISO as user-ready.

## Repository Layout

```text
backgrounds/              OS background images
branding/                 branding assets
bin/                      kakku commands and helpers
dotfiles/                 user config defaults
packages/                 package profile lists
packaging/                local PKGBUILDs
scripts/                  repository checks
system/                   system defaults and shared assets
```

Backgrounds install to `/usr/share/backgrounds/kakku/`. Branding assets install to `/usr/share/kakku/branding/`.

## AI Tooling Context

Repository context for AI tools lives in `AGENTS.md`. Practical context for helping normal users customize and troubleshoot KakkuOS lives in `TWEAKING.md`. Lightweight tool-specific pointers are also provided in `CLAUDE.md`, `.github/copilot-instructions.md`, and `llms.txt`.

## Package Profiles

Default package lists live in `packages/profiles/`:

- `core.txt`: base tools, services, firewall, hardware helpers
- `desktop.txt`: niri, DMS, portals, audio, fonts, desktop apps
- `cli.txt`: shell and terminal tools
- `development.txt`: development tools
- `gaming.txt`: gaming stack
- `media.txt`: media, office, creative tools

`packages/aur.txt` contains AUR defaults such as Chrome, VS Code, Sidra, and LocalSend. `packages/pacman.txt` contains extra repo packages.

## Kakku Command

```bash
kakku help
```

Available commands:

| Command | Purpose |
|---|---|
| `kakku info` | Show OS, kernel, compositor, and shell info. |
| `kakku doctor` | Check expected commands, configs, assets, defaults, and services. |
| `kakku doctor --fix` | Restore missing Kakku user configs and enable expected services. |
| `kakku context` | Print safe system context for AI chats or support requests. |
| `kakku packages` | Show package profile information. |
| `kakku update` | Update repo and AUR packages. |

## Desktop Defaults

Kakku ships a niri config with app launchers, screenshot behavior, portal-friendly window rules, cursor defaults, and shell integrations.

Notable defaults:

- `Mod+Space`: App launcher
- `Mod+Tab`: Workspace overview
- `Mod+T`: Ghostty
- `Mod+E`: Dolphin
- `Mod+B`: Zen Browser
- `Mod+Shift+B`: Toggle top bar
- `Mod+D`: Vesktop
- `Mod+S`: Steam
- `Mod+C`: SpeedCrunch
- `Mod+Y`: Background browser
- `Mod+section`: Keybinding help
- `Print`: Screenshot
- `Mod+Shift+P`: Color picker

Use `Mod+section` to open the niri hotkey overlay. The editable source of truth
is `~/.config/niri/config.kdl`.

## DMS

Kakku installs DMS through `dms-shell-niri` and uses the packaged DMS greeter with greetd.

Kakku ships default DMS settings at:

```text
/usr/share/kakku/dms/settings.defaults.json
```

Those settings provide the KakkuOS theme, bar layout, power-menu hold duration, and shell behavior. User-edited settings remain authoritative after first boot.

For VS Code theming, KakkuOS uses DMS' bundled dynamic theme extension. The
installer and `kakku doctor --fix` apply the local DMS VS Code theme setup when
the required tools are available.

## Defaults

Default apps:

- Web links: Zen Browser
- Secondary browser: Chrome
- Directories: Dolphin
- Video/audio quick playback: mpv
- Images: imv, with Loupe available
- PDFs: Zathura
- Office documents: OnlyOffice

Zen Browser policy defaults install uBlock Origin, Dark Reader, and SponsorBlock.

## System Defaults

Kakku applies a small set of system defaults:

- UFW enabled with denied incoming and allowed outgoing traffic
- `power-profiles-daemon`, `ananicy-cpp`, NetworkManager, Bluetooth, Docker, and Tailscale enabled when available
- Plymouth removed
- Limine timeout set to `1`
- niri portal config installed for screen sharing
- Breeze cursor theme
- Mesa/NVIDIA shader cache size raised for gaming

## License

KakkuOS repository assets and scripts are licensed under the MIT License.
