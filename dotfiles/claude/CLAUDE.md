# Claude Code — KakkuOS

This system runs KakkuOS, a CachyOS/Arch-based Linux desktop with niri (Wayland tiling compositor), DankMaterialShell, Ghostty terminal, fish shell, and Starship prompt.

## System Interaction

- Run `kakku context --json` for full machine-readable system state (configs, services, versions)
- Use `kakku-edit <file> --stdin` or `kakku-edit <file> --content "..."` for safe config edits with backup and auto-rollback on validation failure
- Change log: `~/.local/share/kakku/changelog.jsonl`
- Run `kakku doctor` for health checks

## Key Paths

- Compositor config: `~/.config/niri/config.kdl` (KDL format)
- Shell panel: `~/.config/DankMaterialShell/settings.json`
- Terminal: `~/.config/ghostty/config`
- Shell: `~/.config/fish/config.fish`
- Prompt: `~/.config/starship/starship.toml`
- AI context: `~/.config/kakku/ai-context.md`

## Conventions

- Validate niri config before reloading: `niri validate -c ~/.config/niri/config.kdl`
- Reload niri: `niri msg action load-config-file`
- Restart DMS: `dms restart`
- Package install: `sudo pacman -S` or `paru -S` for AUR
- fish shell syntax for interactive commands
- Super is the Mod key
- Do not edit DMS-generated files under `~/.config/niri/dms/`
- Prefer reversible, user-level changes
