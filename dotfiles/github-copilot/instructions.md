# GitHub Copilot Instructions — KakkuOS

This system runs KakkuOS, a CachyOS/Arch-based Linux desktop with niri (Wayland tiling compositor), DankMaterialShell, Ghostty terminal, fish shell, and Starship prompt.

## When editing config files

- Niri config is KDL format: `~/.config/niri/config.kdl`
- Always validate with `niri validate -c ~/.config/niri/config.kdl` before suggesting reload
- DMS settings are JSON: `~/.config/DankMaterialShell/settings.json`
- Fish config: `~/.config/fish/config.fish`
- Use `kakku-edit <file> --stdin` for safe edits with automatic backup and validation

## Available tools

- `kakku context --json` provides full machine-readable system state including configs
- `kakku doctor` checks system health
- `~/.config/niri/config.kdl` is the keybinding source of truth
- Use `systemctl` and `systemctl --user` for service status
- Change log at `~/.local/share/kakku/changelog.jsonl`

## Conventions

- Package manager: pacman + paru (AUR)
- Wayland-native apps preferred
- fish shell syntax (not bash) for interactive commands
- Super is the mod key in niri
- Prefer user-level changes over system-level changes
