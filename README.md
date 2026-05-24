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

## Package Profiles

Default package lists live in `packages/profiles/`:

- `core.txt`: base tools, services, firewall, hardware helpers
- `desktop.txt`: niri, DMS, portals, audio, fonts, desktop apps
- `cli.txt`: shell and terminal tools
- `development.txt`: development tools
- `gaming.txt`: gaming stack
- `media.txt`: media, office, creative tools

`packages/aur.txt` contains AUR defaults such as Chrome, VS Code, Cider, and LocalSend. `packages/pacman.txt` contains extra repo packages.

## Kakku Command

```bash
kakku help
```

Available commands:

| Command | Purpose |
|---|---|
| `kakku info` | Show OS, kernel, compositor, and shell info. |
| `kakku doctor` | Check expected commands, configs, assets, defaults, and services. |
| `kakku doctor --fix` | Reapply safe local defaults and enable expected services. |
| `kakku services` | Show service active/enabled state. |
| `kakku keybinds` | Print default keybindings. |
| `kakku paths` | Show important Kakku paths. |
| `kakku packages` | Show package profile information. |
| `kakku update` | Update repo and AUR packages. |
| `kakku defaults` | Reapply default applications. |

## Desktop Defaults

Kakku ships a niri config with app launchers, screenshot behavior, portal-friendly window rules, cursor defaults, and shell integrations.

Notable defaults:

- `Mod+Space`: App launcher
- `Mod+Tab`: Workspace overview
- `Mod+T`: Ghostty
- `Mod+E`: Dolphin
- `Mod+B`: Zen Browser
- `Mod+Shift+B`: Chrome
- `Mod+D`: Vesktop
- `Mod+S`: Steam
- `Mod+Y`: Background browser
- `Mod+section`: Keybinding help
- `Print`: Screenshot
- `Mod+Shift+P`: Color picker

Run `kakku keybinds` for the full list.

## DMS

Kakku installs DMS through `dms-shell-niri` and uses the packaged DMS greeter with greetd.

Kakku ships default DMS settings at:

```text
/usr/share/kakku/dms/settings.defaults.json
```

Those settings provide the KakkuOS theme, bar layout, power-menu hold duration, and shell behavior. User-edited settings remain authoritative after first boot.

## Defaults

Run:

```bash
kakku defaults
```

Default apps:

- Web links: Zen Browser
- Secondary browser: Chrome
- Directories: Dolphin
- Video/audio quick playback: mpv
- Images: imv, with Loupe available
- PDFs: Zathura
- Office documents: LibreOffice

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
