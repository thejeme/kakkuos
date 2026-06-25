# KakkuOS System Context

This machine runs KakkuOS, a CachyOS-based Linux desktop.

## Environment

- Compositor: niri (Wayland tiling)
- Shell panel: DankMaterialShell (DMS)
- Terminal: Ghostty
- Shell: fish with Starship prompt
- Browser: Zen Browser (default), Chrome (secondary)
- Editor: VS Code, Neovim
- File manager: Dolphin (GUI), Yazi (TUI)
- Audio: PipeWire + WirePlumber
- Display: Wayland-first, Xwayland Satellite for X11 apps

## Key Config Locations

- `~/.config/niri/config.kdl` — compositor, keybindings, startup, window rules
- `~/.config/DankMaterialShell/settings.json` — bar, launcher, lock, notifications, themes
- `~/.config/fish/config.fish` — shell config
- `~/.config/ghostty/config` — terminal config
- `~/.config/starship/starship.toml` — prompt config
- `~/.config/nvim/init.lua` — neovim config

## Useful Commands

```bash
kakku context          # Human-readable system state
kakku context --json   # Machine-readable full state (configs included)
kakku doctor           # Health check
kakku doctor --fix     # Auto-repair common issues
kakku edit <file> --stdin  # Safe edit with backup, validation, rollback
niri validate -c ~/.config/niri/config.kdl  # Validate niri config
niri msg action load-config-file            # Hot-reload niri config
dms restart            # Restart shell panel
```

## Change Journal

All config edits made through `kakku-edit` are logged to:
`~/.local/share/kakku/changelog.jsonl`

## Package Management

- System packages: `sudo pacman -S <pkg>`
- AUR packages: `paru -S <pkg>` or `yay -S <pkg>`
- Update all: `kakku update`

## Important Notes

- `Mod` key is Super in niri keybindings
- Always validate niri config before reloading
- DMS-generated files under `~/.config/niri/dms/` should not be edited directly
- User settings in `~/.config/DankMaterialShell/settings.json` take priority over defaults
