# Kakku OS

Kakku OS is a CachyOS-based Hyprland desktop profile. The first goal is a reproducible setup repository that can be applied on top of an installed CachyOS Hyprland system. Later phases package the defaults as Arch packages and use those packages in an ISO profile.

## Target Architecture

Kakku OS is built from:

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
    pacman.txt
    aur.txt
  dotfiles/
    hypr/
    waybar/
    rofi/
    kitty/
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
    kakku-theme
  branding/
    wallpaper.svg
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
git clone <repo-url> kakku
cd kakku
chmod +x install.sh
./install.sh
```

The script installs the package list, copies dotfiles into the current user's home directory, sets `zsh` as the login shell when available, and enables common services.

The installer is safe to run more than once. Unchanged config files are skipped, changed local config paths are backed up with a timestamp, and package installs use `--needed`.

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

The default theme is `matcha`.

List installed themes:

```bash
kakku-theme list
```

Apply a theme:

```bash
kakku-theme set blueberry
```

The theme switcher updates the current user's Hyprland, Waybar, Rofi, and Kitty theme fragments.

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

Kakku OS repository assets and scripts are licensed under the MIT License.
