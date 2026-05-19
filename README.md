# KakkuOS

KakkuOS is a CachyOS-based operating system built around niri and DankMaterialShell. It keeps the CachyOS kernel, repositories, hardware support, and performance-focused base, then defines its own desktop session, package set, branding, default applications, and user-facing system behavior.

The current installer builds KakkuOS from an installed CachyOS system. The target is a packaged KakkuOS desktop stack first, then a dedicated KakkuOS ISO once the package set and defaults are stable.

## System Architecture

KakkuOS is built from:

- **Base**: CachyOS (Arch-based)
- **Kernel**: CachyOS kernel
- **Display Server**: Wayland
- **Window Manager**: niri
- **Desktop Shell**: DankMaterialShell (DMS)
- **Terminal**: Ghostty
- **Shell**: fish (default), zsh, bash
- **Prompt**: Starship
- **Browser**: Zen Browser & Firefox
- **File Manager**: Dolphin & yazi
- **Editor**: VS Code & Neovim
- **Theme/Colors**: KakkuOS branding & matugen
- **Audio**: PipeWire
- **CLI**: kakku

KakkuOS uses the following components:

- CachyOS system base
- CachyOS repositories
- KakkuOS niri and DankMaterialShell desktop
- KakkuOS package selection
- KakkuOS branding
- KakkuOS default applications and system behavior
- future KakkuOS installer or ISO image

## Repository Layout

```text
kakku/
  install.sh
  themes/
    default/
      backgrounds/
  packages/
    aur.txt
    pacman.txt
    profiles/
      core.txt
      desktop.txt
      cli.txt
      development.txt
      gaming.txt
      media.txt
  dotfiles/
    yazi/
    lazygit/
    fastfetch/
    zsh/
  system/
    pacman.conf.d/
    environment.d/
    systemd/
  bin/
    kakku
    kakku-*
  branding/
    wallpaper.svg
    wallpaper.png
    logo.svg
    wordmark.svg
    wordmark-compact.svg
    text-logo.txt
  packaging/
    kakku-niri-settings/
    kakku-desktop/
```

OS-provided theme backgrounds are installed under `/usr/share/backgrounds/kakku/themes/`.

## Install

Install KakkuOS from a CachyOS base system.

Install CachyOS first, then run the KakkuOS installer to convert that system into KakkuOS. Use the CachyOS online installer, pick Niri if the installer offers it, or pick the smallest/minimal graphical option available. Avoid installing multiple desktop environments during the CachyOS install.

After rebooting into the new CachyOS system, run the hosted installer. It clones the KakkuOS repository, runs the project installer, installs packages with `--needed`, copies dotfiles, backs up changed local configs, and enables common services when available.

```bash
curl -fsSL https://kakkuos.jeme.app/install.sh \
  | bash
```

Manual local install:

```bash
git clone https://github.com/TheJeme/kakkuos
cd kakkuos
./install.sh
```

The script installs the package list, copies dotfiles into the current user's home directory, installs and configures the DMS greeter for login, disables the default CachyOS Plymouth boot splash, sets `fish` as the login shell when available, and enables common services.

The installer is safe to run more than once. Unchanged config files are skipped, changed local config paths are backed up with a timestamp, and package installs use `--needed`.

On an existing CachyOS install, `install.sh` should be treated as a conversion script. It keeps DMS' generated config files user-owned, but it still installs Kakku packages and defaults, backs up replaced Kakku-owned user config directories, switches the login screen to DMS greeter, applies userspace KakkuOS branding, and updates service defaults. Use the default mode only when the intent is to make that install behave like KakkuOS.

For an existing CachyOS + DMS install where you only want the Kakku user-layer defaults and DMS plugins without changing the login manager, service defaults, or OS branding, run:

```bash
./install.sh --no-system-config
```

For only the default DMS plugins, run:

```bash
kakku-dms-plugins
```

## Default Package Set

KakkuOS uses CachyOS as its system base and ships an opinionated desktop, terminal, gaming, and development package set.

Package lists live in:

- `packages/profiles/core.txt` for base services and system-level tools
- `packages/profiles/desktop.txt` for niri, DankMaterialShell, desktop apps, portals, audio, fonts, and UI tools
- `packages/profiles/cli.txt` for shell, terminal, and modern command-line tools
- `packages/profiles/development.txt` for developer tools
- `packages/profiles/gaming.txt` for gaming tools
- `packages/profiles/media.txt` for media, office, and creative tools
- `packages/pacman.txt` for optional extra repo packages that do not fit a profile yet
- `packages/aur.txt` for AUR packages

By default, `install.sh` installs every profile plus any extra packages listed in `packages/pacman.txt`.

Check that the package profile lists and `kakku-desktop` package dependencies stay aligned:

```bash
scripts/check-package-sync.sh
```

## Kakku Command

Kakku includes a small helper command:

```bash
kakku help
```

Available commands:

| Command | Purpose |
|---|---|
| `kakku info` | Show Kakku, base OS, kernel, and niri/DMS information. |
| `kakku doctor` | Check expected commands, configs, branding assets, defaults, DMS plugins, and key services. |
| `kakku doctor --fix` | Reapply safe local defaults, restore missing skel configs, refresh DMS plugins, apply browser policies, set fish, and enable core services. |
| `kakku services` | Show active/enabled state for key services. |
| `kakku keybinds` | Print KakkuOS default keyboard shortcuts. |
| `kakku paths` | Show important Kakku config and system paths. |
| `kakku packages` | Show installed package profile information. |
| `kakku update` | Update repo and AUR packages. DMS shell updates arrive through normal package updates. |
| `kakku defaults` | Configure default applications with `xdg-mime`. |
| `kakku version` | Show the Kakku version string. |

## CachyOS Base

KakkuOS is a downstream operating system built on CachyOS rather than a replacement for CachyOS infrastructure.

KakkuOS relies on CachyOS for:

- kernel selection and kernel optimization
- graphics drivers and hardware enablement
- CachyOS package repositories
- base system updates
- low-level performance tuning
- installer and hardware support

KakkuOS owns:

- default package selection
- niri, DankMaterialShell, Ghostty, Fastfetch, and shell defaults
- KakkuOS branding
- user-facing desktop defaults
- Kakku packaging and a future ISO image

The practical rule is: KakkuOS should define the user-facing operating system while avoiding unnecessary changes to CachyOS kernel, driver, repository, and hardware behavior.

### Base And Build Tools

These packages make the system useful for source builds, package builds, and day-to-day Git workflows.

| Package | Purpose |
|---|---|
| `base-devel` | Standard Arch build tool group required for `makepkg` and many source builds. |
| `git` | Version control for projects, dotfiles, package sources, and AUR workflows. |
| `paru` | AUR helper available in CachyOS repositories, used by the installer for AUR packages. |
| `pacman-contrib` | Arch maintenance helpers such as `paccache` for package cache cleanup. |
| `cachyos-settings` | CachyOS baseline system tuning package; provides `game-performance` and the default CachyOS ananicy/zram integration. |
| `cachyos-rate-mirrors` | CachyOS mirror ranking helper for improving repository download speed and reliability. |
| `chwd` | CachyOS hardware detection tool. Kakku installs it for inspection and manual troubleshooting, but does not auto-apply driver changes. |

### Niri And DankMaterialShell Desktop

These packages provide the Wayland desktop session and its core user interface.

| Package | Purpose |
|---|---|
| `niri` | Scrollable tiling Wayland compositor. |
| `dms-shell-niri` | DankMaterialShell desktop shell for niri, including bar, launcher, notifications, control center, lock/session UI, wallpaper, and theming integration. |
| `breeze-cursors` | KDE Breeze cursor theme used as Kakku's default pointer style. |
| `xwayland-satellite` | Xwayland support for X11 applications under niri. |
| `xdg-desktop-portal-gnome` | Portal integration used by niri for screen sharing and desktop permissions. |
| `xdg-desktop-portal-gtk` | GTK portal fallback for file pickers and common desktop dialogs. |
| `xdg-utils` | Basic desktop integration commands for opening files, URLs, and default apps. |
| `xdg-user-dirs` | Creates standard user folders like Downloads, Documents, Pictures, and Videos. |
| `swayidle` | Wayland idle manager used by Kakku to start the visual screensaver and then hand off to DMS lock. |
| `matugen` | Wallpaper-based Material color generation used by DMS. |
| `qt6-multimedia` | Qt multimedia libraries used by DMS sound and media components. |
| `qt6-multimedia-ffmpeg` | Qt multimedia backend used by DMS media components. |
| `qt6ct-kde` | Qt 6 configuration tool from the AUR, used with `QT_QPA_PLATFORMTHEME=qt6ct` for Qt/KDE app theming outside Plasma. |
| `wtype` | Wayland typing helper used by DMS clipboard and plugin paste actions. |
| `power-profiles-daemon` | Power profile backend used by DMS settings and quick controls. |
| `i2c-tools` | External display brightness support used by DMS brightness controls. |
| `ghostty` | GPU-accelerated terminal emulator. |
| `dolphin` | Graphical file manager. |
| `zen-browser-bin` | Default Firefox-based web browser. |
| `firefox` | Firefox browser, kept as a fallback for web links if Zen is unavailable. |
| `google-chrome` | Google Chrome from the AUR, installed by the default AUR package list. |
| `vesktop` | Custom Discord client for communities, gaming, and development groups. |
| `greetd-dms-greeter-git` | DMS login greeter for greetd, replacing the previous text-based tuigreet login screen. |
| `dsearch-bin` | DankSearch filesystem search backend used by the DMS launcher when typing `/`. |

Kakku ships `/usr/share/xdg-desktop-portal/niri-portals.conf` so niri sessions route portal requests through `xdg-desktop-portal-gnome` with GTK as fallback. Without this, apps such as Vesktop can open the screen share picker but fail with no video source.

Kakku installs DMS through the repository package `dms-shell-niri`. That split package pulls in the base `dms-shell` package and provides the niri compositor integration. Kakku configures greetd to launch the packaged DMS greeter with `/usr/bin/dms-greeter --command niri -p /usr/share/quickshell/dms`, so the login screen uses the DMS greeter UI instead of Kakku's old tuigreet wrapper. Kakku also ships a niri default config in `~/.config/niri` with Kakku-owned DMS keybindings, Kakku screenshot paths, and DMS-friendly window and layer rules. DMS-generated files under `~/.config/niri/dms` are left to DMS and are not required for niri to start.

The install script also runs `kakku-dms-plugins --no-restart`, which installs or updates these DMS plugins under `~/.config/DankMaterialShell/plugins/`:

| Plugin | Install directory | Source |
|---|---|---|
| AI Assistant | `AIAssistant` | `https://github.com/devnullvoid/dms-ai-assistant` |
| Calculator | `Calculator` | `https://github.com/rochacbruno/DankCalculator` |

Run `kakku dms-plugins` later to update both plugin checkouts and restart DMS.

Kakku does not replace DMS' generated `settings.json`, `plugin_settings.json`, cache, or session state. It merges missing defaults from `/usr/share/kakku/dms/plugin_settings.defaults.json` and `/usr/share/kakku/dms/settings.defaults.json`, so first boot gets the Kakku theme, bar layout, plugin defaults, and shell behavior while user changes and DMS-written values remain authoritative after that.

### Screensaver And Idle

Kakku keeps DMS as the secure lock screen and adds a lightweight visual screensaver in front of it. The visual layer is terminal-based, starts in Ghostty when available, and uses `cmatrix` by default because it is native and much smoother than repainting the terminal from shell. Pointer motion and keypresses both exit the screensaver. The fallback renderer uses the ASCII logo from `/usr/share/kakku/screensaver/kakku.txt`, and users can override that logo with `~/.config/kakku/screensaver.txt`.

The `kakku-idle.service` user service runs `kakku-idle`, which starts the visual screensaver after 5 minutes of idle time, stops it on activity, and hands off to `dms ipc call lock lock` after 15 minutes. The defaults can be changed with `KAKKU_SCREENSAVER_TIMEOUT`, `KAKKU_LOCK_TIMEOUT`, `KAKKU_SCREENSAVER_CMD`, `KAKKU_SCREENSAVER_STOP_CMD`, and `KAKKU_LOCK_CMD`. For the user service, put overrides in `~/.config/kakku/idle.env`.

Useful commands:

```bash
kakku screensaver
kakku screensaver --stop
kakku idle
```

### Audio, Network, And Devices

These packages cover common laptop and desktop hardware needs.

| Package | Purpose |
|---|---|
| `pipewire` | Modern Linux audio and media server. |
| `pipewire-pulse` | PulseAudio compatibility layer for apps that expect PulseAudio. |
| `wireplumber` | PipeWire session manager. |
| `networkmanager` | Network connection management. |
| `bluez` | Bluetooth protocol stack. |
| `bluez-utils` | Bluetooth command-line tools and service helpers. |
| `tailscale` | WireGuard-based private mesh VPN for connecting personal machines and servers. |
| `proton-vpn-gtk-app` | Proton VPN graphical client. |

The installer enables `NetworkManager`, `bluetooth`, `docker`, `tailscaled`, `ananicy-cpp`, and `power-profiles-daemon` when available.

### Shell And Prompt

Kakku uses `fish` as the default login shell, while keeping zsh and bash defaults available for users who prefer them.

| Package | Purpose |
|---|---|
| `fish` | Default interactive shell. |
| `zsh` | Alternative interactive shell with matching prompt and navigation defaults. |
| `starship` | Fast cross-shell prompt. |
| `zoxide` | Smarter directory jumping. Kakku initializes it as `cd`, so frequent directories become faster to reach. |

### Modern CLI Tools

Kakku includes modern replacements for common Unix commands while keeping behavior guarded in fish, zsh, and bash config, so aliases are only created when the tool exists.

| Package | Replaces/Supports | Purpose |
|---|---|---|
| `eza` | `ls` | Better directory listing with icons, Git state, and tree views. |
| `bat` | `cat` | Syntax-highlighted file viewing with sane paging behavior. |
| `ripgrep` | `grep` | Fast recursive text search. |
| `fd` | `find` | Fast file and directory search with simpler defaults. |
| `fzf` | Shell selection UI | Fuzzy file, directory, and history selection. Kakku configures it to use `fd`. |
| `jq` | JSON inspection/editing | Essential command-line tool for reading and transforming JSON. |
| `sd` | `sed` for simple replacements | Clearer command-line find/replace. |
| `curl` | HTTP client | Required by DMS AI Assistant and useful for API/debug workflows. |
| `duf` | `df` | Easier disk usage overview. |
| `dust` | `du` | Easier directory size inspection. |
| `procs` | `ps` | More readable process listing. |
| `tealdeer` | `tldr` client | Fast practical command examples. |
| `unzip` | ZIP archives | Basic ZIP archive extraction. |
| `7zip` | 7z and archive handling | Archive support used by tools such as Yazi. |
| `chafa` | Terminal image preview | Fallback image preview support for terminal tools. |
| `imagemagick` | Image processing | Image/font preview support and general image conversion tools. |
| `poppler` | PDF tools | PDF preview support for terminal file workflows. |
| `resvg` | SVG rendering | SVG preview/rendering support. |
| `wl-clipboard` | Wayland clipboard | Clipboard support for terminal tools. |
| `less` | Pager | Default pager for manuals and command output. |
| `man-db` | Manual pages | Manpage database and `man` command support. |
| `man-pages` | Manual page content | Common Linux and POSIX documentation. |
| `cmatrix` | Visuals/Screensaver | Classic trailing "Matrix" code animation in your terminal. |
| `cbonsai` | Visuals/Fun | Grows an ASCII bonsai tree in your terminal. |
| `cowsay` | Fun | Classic CLI tool for generating ASCII art text bubbles. |
| `sl` | `ls` typo | Steam locomotive animation for when you accidentally type `sl` instead of `ls`. |
| `tty-clock` | Widget | A clean digital clock for the terminal. |
| `musikcube-bin` | Media Player | Modern and sleek terminal-based music player for local files. |
| `httpie` | HTTP Client | User-friendly, colorized command-line HTTP client (modern `curl` alternative). |
| `glow` | Markdown Viewer | Renders Markdown files beautifully directly in the terminal. |
| `trippy` | Network Diagnostics | Modern network diagnostic TUI combining `ping` and `traceroute`. |
| `pacseek` | Package Manager | Beautiful terminal user interface for searching and installing Arch/AUR packages. |

Configured shell behavior:

- `ls`, `la`, `ll`, and `lt` use `eza`
- `cat` uses `bat`
- `grep` uses `ripgrep`
- `find` uses `fd`
- `cd` uses `zoxide`
- `df` uses `duf`
- `du` uses `dust`
- `ps` uses `procs`
- `helpme` uses `tldr`
- `fzf` uses `fd` for file and directory discovery
- `y` and `fm` open `yazi`
- `yy` opens `yazi` and changes the shell to the selected directory on exit

### System Monitoring And Identity

| Package | Purpose |
|---|---|
| `inxi` | Hardware and system information tool, useful for debugging and support. |
| `fastfetch` | Terminal system summary with Kakku ASCII branding. |
| `btop` | Interactive process, CPU, memory, disk, and network monitor. |
| `speedcrunch` | Fast desktop calculator for technical and everyday calculations. |

### Fonts

| Package | Purpose |
|---|---|
| `fontconfig` | Font discovery and configuration system. |
| `noto-fonts` | Broad default text font coverage. |
| `noto-fonts-cjk` | Chinese, Japanese, and Korean text support. |
| `noto-fonts-emoji` | Emoji rendering support. |
| `ttf-jetbrains-mono-nerd` | Terminal font with developer icons for Ghostty, Starship, DMS, and `eza`. |

### Gaming

Kakku includes a gaming-ready baseline while still relying on CachyOS for optimized kernels, drivers, Mesa, and system tuning.

| Package | Purpose |
|---|---|
| `cachyos-gaming-meta` | CachyOS gaming dependency stack, including Proton/Wine helpers, codec/runtime libraries, `umu-launcher`, `protontricks`, `winetricks`, and Vulkan tools. |
| `cachyos-gaming-applications` | CachyOS gaming app bundle for Steam, Heroic, Lutris, Gamescope, GOverlay, MangoHud, and related 32-bit overlay support. |
| `steam` | Steam client and Proton game library. |
| `heroic-games-launcher` | Epic Games, GOG, and Amazon Games launcher. |
| `lutris` | Launcher and runner manager for Wine, Proton, emulators, and third-party game stores. |
| `mangohud` | Performance overlay for Vulkan/OpenGL games. |
| `gamescope` | Nested game compositor useful for scaling, HDR workflows, and Steam-style sessions. |
| `goverlay` | Graphical MangoHud configuration tool. |
| `vesktop` | Common voice/chat companion for gaming sessions and communities. |

Useful launch options:

```text
game-performance %command%
mangohud %command%
mangohud game-performance %command%
```

Kakku follows CachyOS' `game-performance` wrapper instead of enabling `gamemode` by default. `game-performance` temporarily switches `power-profiles-daemon` to the performance profile while the game runs, then restores the previous profile when the game exits. `ananicy-cpp` is enabled as part of the CachyOS settings baseline, so avoiding `gamemode` also avoids the conflict CachyOS documents between those two process tuners.

Kakku also raises the Mesa and NVIDIA shader cache size limits through `/etc/environment.d/kakku.conf`. This avoids needless shader cache eviction in large games without preallocating the full cache size.

### Media And Creative Tools

These packages make the default install useful for media playback, screen recording, video editing, image editing, and documents.

| Package | Purpose |
|---|---|
| `mpv` | Lightweight, high-quality media player. |
| `imv` | Keyboard-driven image viewer for Wayland. |
| `loupe` | Friendly graphical image viewer. Installed as a fallback while `imv` remains the MIME default. |
| `zathura` | Keyboard-driven document viewer used as the default PDF app. |
| `zathura-pdf-mupdf` | PDF backend for Zathura. |
| `ffmpegthumbnailer` | Video thumbnail generation for file previews. |
| `obs-studio` | Screen recording and streaming. |
| `kdenlive` | Non-linear video editor. |
| `pinta` | Simple image editor for quick edits and annotations. |
| `libreoffice-fresh` | Office suite for documents, spreadsheets, and presentations. |
| `cider` | Apple Music client. A highly customizable, modern, open-source player. |

### Development And Containers

| Package | Purpose |
|---|---|
| `docker` | Container runtime. |
| `docker-compose` | Compose workflow for multi-container development stacks. |
| `github-cli` | GitHub command-line tool, installed as `gh`. |
| `nodejs` | JavaScript runtime for web tooling and server-side development. |
| `npm` | Node package manager and package registry CLI. |
| `pnpm` | Fast, disk-efficient package manager for JavaScript and TypeScript projects. |
| `neovim` | Modern Vim-based terminal editor. Kakku ships a LazyVim-based default config with common web, config, Markdown, Docker, and TOML extras in `~/.config/nvim`. |
| `lazygit` | Terminal UI for Git repositories. |
| `lazydocker` | Terminal UI for Docker containers, images, volumes, and logs. |
| `git-delta` | Better Git diff viewer used by the Lazygit config. |
| `openai-codex` | OpenAI Codex CLI |
| `tmux` | Terminal multiplexer for persistent shell sessions, panes, and remote work. |
| `yazi` | Fast terminal file manager. Kakku keeps Dolphin as the graphical file manager and uses Yazi for terminal workflows. |
| `visual-studio-code-bin` | Visual Studio Code from the AUR. Kept in `packages/aur.txt` because it is not a normal repo package. |
| `localsend-bin` | LocalSend from the AUR for local network file sharing between devices. |

## Keybindings

Kakku ships a niri keybinding config in `~/.config/niri/config.kdl`. Run `kakku keybinds` for the full configured shortcut list. The most important DMS actions are listed below so they are easy to audit or rebind.

## DankMaterialShell Actions

| Action | Command |
|---|---|
| Launcher | `dms ipc call spotlight toggle` |
| Clipboard | `dms ipc call clipboard toggle` |
| Notifications | `dms ipc call notifications toggle` |
| Settings | `dms ipc call settings focusOrToggle` |
| Wallpaper browser | `dms ipc call dankdash wallpaper` |
| Color picker | `dms color pick -a` |
| Lock | `dms ipc call lock lock` |
| Screensaver | `kakku screensaver` |

## Default Applications

KakkuOS configures common default applications with:

```bash
kakku defaults
```

Defaults include Zen Browser for web links, Dolphin for directories, mpv for audio/video, imv for images, Zathura for PDFs, and LibreOffice applications for office documents. Firefox remains a web-link fallback if Zen is unavailable.

Zen Browser is configured with a policy file that force-installs uBlock Origin, Dark Reader, and SponsorBlock from Mozilla Add-ons.

## Boot Splash

CachyOS ISOs enable Plymouth by default for the graphical boot splash. KakkuOS disables that splash during installation. The internal helper removes the Plymouth hook from `/etc/mkinitcpio.conf` when present, rebuilds initramfs with `mkinitcpio -P` only when that file changed, and leaves a `.kakku.bak` backup for the edited file.

## Phase 2: Package The Defaults

The `packaging/kakku-niri-settings` package installs KakkuOS defaults into `/etc/skel`, mirroring the model used by distribution settings packages. New users created after installation inherit those defaults.

```bash
cd packaging/kakku-niri-settings
makepkg -si
```

## Phase 3: Install A Desktop Meta-Package

The `packaging/kakku-desktop` package depends on the default Kakku desktop stack.

```bash
cd packaging/kakku-desktop
makepkg -si
```

After the packages are published in a repository, a full desktop install becomes:

```bash
sudo pacman -S kakku-desktop
```

## Phase 4: Build A KakkuOS ISO

KakkuOS ISO work should use CachyOS' live ISO tooling instead of maintaining a separate ArchISO stack.

The scaffold is under:

```bash
iso/
```

Prepare a CachyOS-Live-ISO checkout with the KakkuOS overlay staged:

```bash
iso/build-kakku-iso.sh --prepare-only
```

Build through CachyOS' `buildiso.sh`:

```bash
iso/build-kakku-iso.sh
```

This is not a finished release pipeline yet. The scaffold builds a temporary local package repo for `kakku-niri-settings` and `kakku-desktop`, injects it into the CachyOS live tree, removes the CachyOS GUI installer packages, adds `kakku-desktop` and `cachyos-cli-installer-new` to the ISO package list, and creates a `kakku-install` command for the live environment. The next ISO milestone is wiring the CLI installer profile so installed systems select KakkuOS defaults directly.

## License

KakkuOS repository assets and scripts are licensed under the MIT License.
