# KakkuOS Tweaking Guide

This guide is for normal KakkuOS users and AI assistants helping them customize a running system. It focuses on practical desktop tweaks, where settings live, and what to restart or reload after a change.

## What KakkuOS Is

KakkuOS is a CachyOS-based desktop system with Kakku defaults on top. CachyOS provides the base OS, kernel, drivers, package repositories, gaming support, and performance tuning. KakkuOS provides the desktop experience: niri, DankMaterialShell, Ghostty, fish, Starship, browser defaults, wallpapers, keybindings, themes, helper commands, and service defaults.

When tweaking KakkuOS, most changes are user-level config changes under `~/.config`, not low-level OS changes.

## Main Places To Tweak

### DankMaterialShell

DMS controls the top bar, launcher, lock screen, power menu, notifications, audio/brightness OSDs, wallpaper UI, and many visual settings.

Common files and commands:

```bash
~/.config/DankMaterialShell/settings.json
dms restart
dms doctor
```

Use `dms restart` after changing DMS settings manually or when DMS behaves oddly after monitor reconnects.

### Niri

niri is the Wayland compositor. It controls windows, workspaces, keybindings, monitor layout, screenshots, and startup commands.

Common files and commands:

```bash
~/.config/niri/config.kdl
~/.config/niri/dms/
niri validate -c ~/.config/niri/config.kdl
niri msg action load-config-file
```

Always validate the config before reloading it. If a DMS-generated file says not to edit it, prefer changing the setting through DMS or placing custom rules in the main config.

### Keybindings

User keybindings are in:

```bash
~/.config/niri/config.kdl
```

Useful examples:

```text
Mod+Space      DMS launcher
Mod+T          Ghostty terminal
Mod+E          Dolphin file manager
Mod+B          Zen Browser
Mod+Shift+L    Lock screen
Print          Screenshot picker
```

After editing keybindings:

```bash
niri validate -c ~/.config/niri/config.kdl
niri msg action load-config-file
```

### Idle, Lock, And Screensaver

KakkuOS uses `swayidle`, `niri-screensaver-ctl`, and DMS lock commands for idle behavior.

The default behavior is:

- 15 minutes idle: start the screensaver
- activity resumes: stop the screensaver
- 60 minutes idle: lock the screen
- before sleep: lock the screen

This behavior is configured in `~/.config/niri/config.kdl` with a `spawn-at-startup "swayidle"` line.

### Monitors

Monitor state is Wayland/niri/DMS related. Useful commands:

```bash
niri msg outputs
dms randr
dms dpms off
dms dpms on
```

If the launcher or bar acts strange after physically turning a monitor off and on, try:

```bash
dms restart
```

Using DPMS commands to turn displays off is often cleaner than using the monitor power button, because it avoids a full disconnect/reconnect event.

### Wallpaper And Theme

KakkuOS wallpapers are installed under:

```bash
/usr/share/backgrounds/kakku/
```

Kakku branding and DMS theme defaults are under:

```bash
/usr/share/kakku/branding/
/usr/share/kakku/dms/
```

DMS settings and the wallpaper browser are usually the easiest way to change wallpaper or theme behavior.

### Browser Defaults

KakkuOS uses Zen Browser as the default browser and Chrome as a secondary browser. Browser policies are managed by Kakku helper scripts.

Useful commands:

```bash
kakku defaults
kakku browser-theme
kakku vscode-theme
kakku doctor
```

### Default Apps

Reapply default apps with:

```bash
kakku defaults
```

Defaults include Zen Browser for web links, Dolphin for folders, mpv for media, imv for images, Zathura for PDFs, and LibreOffice for office files.

### Services

Check Kakku service status with:

```bash
kakku services
```

Run a general health check with:

```bash
kakku doctor
```

Generate a support summary that can be pasted into an AI chat or support request:

```bash
kakku context
```

Try safe repair steps with:

```bash
kakku doctor --fix
```

## Safe Troubleshooting Flow

For most desktop issues:

1. Check what changed recently.
2. Validate config before reloads.
3. Restart only the affected layer first.
4. Use `kakku doctor` for broader checks.
5. Reboot only when service/session state is unclear.

Useful restart/reload commands:

```bash
dms restart
niri validate -c ~/.config/niri/config.kdl
niri msg action load-config-file
systemctl --user restart dms.service
```

When asking an AI assistant for help, include what you want to change and the output of:

```bash
kakku context
```

## Advice For AI Assistants

When helping a non-developer user:

- explain what a setting does in plain language;
- prefer GUI or user-level config changes before system-level changes;
- show exact files and commands;
- validate before reloading niri;
- ask for `kakku context` when system details are needed;
- avoid deleting or overwriting user config;
- make backups before large manual edits;
- mention when logout or reboot is required;
- do not suggest rebuilding packages or ISO images unless the user is actually developing KakkuOS.
