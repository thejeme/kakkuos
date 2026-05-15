# KakkuOS

KakkuOS is a CachyOS-based Hyprland desktop profile. The first goal is a reproducible setup repository that can be applied on top of an installed CachyOS Hyprland system. Later phases package the defaults as Arch packages and use those packages in an ISO profile.

## Target Architecture

KakkuOS is built from:

- CachyOS base
- CachyOS repositories
- Kakku Hyprland configuration
- Kakku package selection
- Kakku branding
- Optional custom installer or ISO profile

## Repository Layout

```text
kakku/
  install.sh
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
    hypr/
    waybar/
    rofi/
    kitty/
    mako/
    fastfetch/
    zsh/
  system/
    pacman.conf.d/
    environment.d/
    systemd/
  themes/
    matcha/
    blueberry/
    strawberry/
    funfetti/
    velvet/
    caramel/
    mocha/
    tiramisu/
    vanilla/
  bin/
    kakku
    kakku-theme
    kakku-screenshot
  branding/
    wallpaper.svg
    wallpaper.png
    logo.svg
    wordmark.svg
    wordmark-compact.svg
    fastfetch-logo.txt
  packaging/
    kakku-hyprland-settings/
    kakku-desktop/
```

## Phase 1: Apply On Top Of CachyOS Hyprland

Install CachyOS Hyprland first, then run:

```bash
git clone https://github.com/TheJeme/kakkuos
cd kakkuos
chmod +x install.sh
./install.sh
```

The script installs the package list, copies dotfiles into the current user's home directory, sets `zsh` as the login shell when available, and enables common services.

The installer is safe to run more than once. Unchanged config files are skipped, changed local config paths are backed up with a timestamp, and package installs use `--needed`.

## Default Package Set

Kakku keeps CachyOS as the operating system base and adds an opinionated desktop, terminal, gaming, and development layer on top.

Package lists live in:

- `packages/profiles/core.txt` for base services and system-level tools
- `packages/profiles/desktop.txt` for Hyprland, desktop apps, portals, audio, screenshots, notifications, fonts, and UI tools
- `packages/profiles/cli.txt` for shell, terminal, and modern command-line tools
- `packages/profiles/development.txt` for developer tools
- `packages/profiles/gaming.txt` for gaming tools
- `packages/profiles/media.txt` for media, office, and creative tools
- `packages/pacman.txt` for optional extra repo packages that do not fit a profile yet
- `packages/aur.txt` for AUR packages

By default, `install.sh` installs every profile plus any extra packages listed in `packages/pacman.txt`.

Check that the profile package lists and `kakku-desktop` package dependencies stay aligned:

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
| `kakku info` | Show Kakku, base OS, kernel, Hyprland, and current theme information. |
| `kakku doctor` | Check expected commands, configs, theme paths, wallpaper, and key services. |
| `kakku services` | Show active/enabled state for key services. |
| `kakku keybinds` | Print KakkuOS default keyboard shortcuts. |
| `kakku paths` | Show important Kakku config and system paths. |
| `kakku packages` | Show installed package profile information. |
| `kakku theme list` | List available themes. |
| `kakku theme current` | Show the current theme. |
| `kakku theme set <theme>` | Apply a theme. |
| `kakku update` | Run a normal interactive system update with `pacman`, then AUR updates with `paru` or `yay` if available. |
| `kakku version` | Show the Kakku version string. |

## Relationship To CachyOS

Kakku is intended to stay a thin CachyOS-based desktop profile, not a deep fork.

CachyOS owns:

- kernel selection and kernel optimization
- graphics drivers and hardware enablement
- CachyOS package repositories
- base system updates
- low-level performance tuning
- installer and hardware support

Kakku owns:

- default package selection
- Hyprland, Waybar, Rofi, Kitty, Mako, Fastfetch, and Zsh defaults
- Kakku themes
- Kakku branding
- user-facing desktop defaults
- optional Kakku packaging and ISO profile later

The practical rule is: Kakku should customize the desktop experience while avoiding unnecessary changes to CachyOS kernel, driver, bootloader, repository, and hardware behavior.

### Base And Build Tools

These packages make the system useful for source builds, package builds, and day-to-day Git workflows.

| Package | Purpose |
|---|---|
| `base-devel` | Standard Arch build tool group required for `makepkg` and many source builds. |
| `git` | Version control for projects, dotfiles, package sources, and AUR workflows. |
| `pacman-contrib` | Arch maintenance helpers such as `paccache` for package cache cleanup. |

### Hyprland Desktop

These packages provide the Wayland desktop session and its core user interface.

| Package | Purpose |
|---|---|
| `hyprland` | Main Wayland compositor and window manager. |
| `hyprpaper` | Wallpaper daemon used by the default Kakku Hyprland config. |
| `hypridle` | Idle daemon for locking, sleeping, or turning off displays after inactivity. |
| `hyprlock` | Lock screen for Hyprland. |
| `hyprpicker` | Wayland color picker for grabbing colors from the screen. |
| `hyprsunset` | Hyprland-native blue-light and gamma adjustment utility. |
| `xdg-desktop-portal-hyprland` | Portal integration for screen sharing, file pickers, and desktop app permissions. |
| `xdg-utils` | Basic desktop integration commands for opening files, URLs, and default apps. |
| `xdg-user-dirs` | Creates standard user folders like Downloads, Documents, Pictures, and Videos. |
| `waybar` | Top bar for workspaces, clock, tray, audio, network, and battery state. |
| `rofi-wayland` | App launcher and window switcher. |
| `kitty` | GPU-accelerated terminal emulator. |
| `dolphin` | Graphical file manager. |
| `firefox` | Default web browser. |
| `discord` | Voice and chat client for communities, gaming, and development groups. |
| `mako` | Notification daemon for Wayland desktops. |
| `hyprpolkitagent` | Hyprland-native graphical authentication prompts for admin actions. |
| `hyprqt6engine` | Hyprland Qt 6 theme engine from the AUR, used by Kakku's environment defaults. |

Kakku autostarts `waybar`, `hyprpaper`, `mako`, `hypridle`, `hyprsunset`, and `hyprpolkitagent` from the Hyprland config.

### Audio, Network, And Devices

These packages cover common laptop and desktop hardware needs.

| Package | Purpose |
|---|---|
| `pipewire` | Modern Linux audio and media server. |
| `pipewire-pulse` | PulseAudio compatibility layer for apps that expect PulseAudio. |
| `wireplumber` | PipeWire session manager. |
| `pamixer` | Command-line audio volume control, useful for keybindings and Waybar. |
| `networkmanager` | Network connection management. |
| `bluez` | Bluetooth protocol stack. |
| `bluez-utils` | Bluetooth command-line tools and service helpers. |
| `brightnessctl` | Brightness control for laptops and monitor backlights. |
| `tailscale` | WireGuard-based private mesh VPN for connecting personal machines and servers. |
| `proton-vpn-gtk-app` | Proton VPN graphical client. |

The installer enables `NetworkManager`, `bluetooth`, `docker`, and `tailscaled` when available.

### Shell And Prompt

Kakku uses `zsh` with a modern prompt and navigation defaults.

| Package | Purpose |
|---|---|
| `zsh` | Default interactive shell. |
| `starship` | Fast cross-shell prompt. |
| `zoxide` | Smarter directory jumping. Kakku initializes it as `cd`, so frequent directories become faster to reach. |

### Modern CLI Tools

Kakku includes modern replacements for common Unix commands while keeping behavior guarded in `.zshrc`, so aliases are only created when the tool exists.

| Package | Replaces/Supports | Purpose |
|---|---|---|
| `eza` | `ls` | Better directory listing with icons, Git state, and tree views. |
| `bat` | `cat` | Syntax-highlighted file viewing with sane paging behavior. |
| `ripgrep` | `grep` | Fast recursive text search. |
| `fd` | `find` | Fast file and directory search with simpler defaults. |
| `fzf` | Shell selection UI | Fuzzy file, directory, and history selection. Kakku configures it to use `fd`. |
| `jq` | JSON inspection/editing | Essential command-line tool for reading and transforming JSON. |
| `sd` | `sed` for simple replacements | Clearer command-line find/replace. |
| `duf` | `df` | Easier disk usage overview. |
| `dust` | `du` | Easier directory size inspection. |
| `procs` | `ps` | More readable process listing. |
| `tealdeer` | `tldr` client | Fast practical command examples. |
| `unzip` | ZIP archives | Basic ZIP archive extraction. |
| `less` | Pager | Default pager for manuals and command output. |
| `man-db` | Manual pages | Manpage database and `man` command support. |
| `man-pages` | Manual page content | Common Linux and POSIX documentation. |

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
| `ttf-jetbrains-mono-nerd` | Terminal font with developer icons for Kitty, Starship, Waybar, and `eza`. |

### Gaming

Kakku includes a gaming-ready baseline while still relying on CachyOS for optimized kernels, drivers, Mesa, and system tuning.

| Package | Purpose |
|---|---|
| `steam` | Steam client and Proton game library. |
| `heroic-games-launcher` | Epic Games, GOG, and Amazon Games launcher. |
| `protonup-qt` | GUI for installing Proton-GE and compatibility tools. |
| `mangohud` | Performance overlay for Vulkan/OpenGL games. |
| `gamescope` | Nested game compositor useful for scaling, HDR workflows, and Steam-style sessions. |
| `gamemode` | Lets games request temporary performance-oriented system tuning. |
| `discord` | Common voice/chat companion for gaming sessions and communities. |

Useful launch options:

```text
gamemoderun %command%
mangohud %command%
mangohud gamemoderun %command%
```

### Media And Creative Tools

These packages make the default install useful for media playback, screen recording, video editing, image editing, and documents.

| Package | Purpose |
|---|---|
| `mpv` | Lightweight, high-quality media player. |
| `obs-studio` | Screen recording and streaming. |
| `kdenlive` | Non-linear video editor. |
| `pinta` | Simple image editor for quick edits and annotations. |
| `libreoffice-fresh` | Office suite for documents, spreadsheets, and presentations. |

### Development And Containers

| Package | Purpose |
|---|---|
| `docker` | Container runtime. |
| `docker-compose` | Compose workflow for multi-container development stacks. |
| `github-cli` | GitHub command-line tool, installed as `gh`. |
| `neovim` | Modern Vim-based terminal editor for coding and config editing. |
| `lazygit` | Terminal UI for Git repositories. |
| `lazydocker` | Terminal UI for Docker containers, images, volumes, and logs. |
| `tmux` | Terminal multiplexer for persistent shell sessions, panes, and remote work. |
| `visual-studio-code-bin` | Visual Studio Code from the AUR. Kept in `packages/aur.txt` because it is not a normal repo package. |
| `localsend-bin` | LocalSend from the AUR for local network file sharing between devices. |

### Wayland Screenshot Tools

| Package | Purpose |
|---|---|
| `grim` | Captures screenshots on Wayland. |
| `slurp` | Selects a screen region, commonly used together with `grim`. |
| `swappy` | Annotates screenshots after capture. |
| `playerctl` | Controls media playback from keybindings or scripts. |

Default Hyprland keybindings include:

- `Print` for region screenshot and annotation via `kakku-screenshot region`
- `Shift+Print` for full-screen screenshot saved under `~/Pictures/Screenshots` via `kakku-screenshot full`
- media keys through `playerctl`
- volume keys through `pamixer`
- brightness keys through `brightnessctl`
- `Super+L` to lock with `hyprlock`

## Themes

Kakku includes these cake-style themes:

- `matcha`
- `blueberry`
- `strawberry`
- `tiramisu`
- `funfetti`
- `velvet`
- `caramel`
- `mocha`
- `vanilla`
- `honey`

The default theme is `matcha`.

List installed themes:

```bash
kakku-theme list
```

Show the current theme:

```bash
kakku-theme current
```

Apply a theme:

```bash
kakku-theme set blueberry
```

The theme switcher updates the current user's Hyprland, Hyprlock, Hyprqt6engine, Waybar, Rofi, Kitty, and Mako theme fragments. It also tries to reload Hyprland and Mako. Open terminal, launcher, and Qt application windows may need to be restarted to pick up the new theme.

## Phase 2: Package The Defaults

The `packaging/kakku-hyprland-settings` package installs Kakku defaults into `/etc/skel`, mirroring the model used by distribution settings packages. New users created after installation inherit those defaults.

```bash
cd packaging/kakku-hyprland-settings
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

## License

KakkuOS repository assets and scripts are licensed under the MIT License.
