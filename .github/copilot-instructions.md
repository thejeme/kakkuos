# KakkuOS Copilot Instructions

Read `AGENTS.md` at the repository root before making suggestions. For normal-user desktop customization and troubleshooting, also read `TWEAKING.md`.

KakkuOS is a layered CachyOS desktop distribution. CachyOS provides the base OS, kernel, repositories, hardware support, gaming stack, and performance tuning. This repository owns the Kakku desktop layer: niri and DankMaterialShell defaults, package profiles, install scripts, helper commands, branding, browser policies, greetd config, packaging, and ISO overlays.

When editing:

- Keep direct-install behavior in `install.sh` and packaged behavior under `packaging/` aligned.
- Keep package profiles and `packaging/kakku-desktop/PKGBUILD` in sync.
- Keep niri keybindings in `dotfiles/niri/config.kdl` and `bin/kakku` help text in sync.
- Avoid overwriting user-owned config unless the command is explicitly a defaults or repair path.
- Prefer idempotent Bash and simple package-list files.
- For non-developer requests, prefer user-level DMS/niri settings, exact commands, config validation, and reversible changes over packaging or ISO work.
