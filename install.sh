#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

# Non-interactive installs are the default. Set `KAKKU_NONINTERACTIVE=0` to
# run interactively. When non-interactive, add `--noconfirm` to pacman/AUR
# helper flags so the script doesn't pause for user confirmation.
KAKKU_NONINTERACTIVE="${KAKKU_NONINTERACTIVE:-1}"
KAKKU_SYSTEM_CONFIG="${KAKKU_SYSTEM_CONFIG:-1}"

# Simple CLI parsing: `--interactive` or `-i` will force interactive mode
# (script will prompt for pacman/AUR confirmations). Default is non-interactive.
print_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -i, --interactive   Run interactively (ask for confirmations)
  --no-system-config  Skip login manager, service, and OS branding changes
  -h, --help          Show this help
EOF
}

die() {
  echo "$1" >&2
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local command_name="$1"

  if ! has_command "$command_name"; then
    die "Missing required command: $command_name"
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -i|--interactive)
      KAKKU_NONINTERACTIVE=0
      shift
      ;;
    --no-system-config)
      KAKKU_SYSTEM_CONFIG=0
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

pacman_flags=("-Syu" "--needed")
aur_helper_flags=("-S" "--needed")
if [[ "$KAKKU_NONINTERACTIVE" == "1" ]]; then
  pacman_flags+=("--noconfirm")
  aur_helper_flags+=("--noconfirm")
fi

read_package_list() {
  local file="$1"

  if [[ -f "$file" ]]; then
    sed -E '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$file"
  fi
}

paths_match() {
  local source="$1"
  local target="$2"

  if [[ -d "$source" && -d "$target" ]]; then
    diff -qr "$source" "$target" >/dev/null 2>&1
  elif [[ -f "$source" && -f "$target" ]]; then
    cmp -s "$source" "$target"
  else
    return 1
  fi
}

backup_existing_path() {
  local target="$1"
  local backup="$target.bak.$(date +%Y%m%d%H%M%S)"

  mv "$target" "$backup"
  echo "Backed up $target to $backup"
}

copy_config_dir() {
  local name="$1"
  local source="$REPO_DIR/dotfiles/$name"
  local target="$HOME/.config/$name"

  if [[ -d "$source" ]]; then
    if [[ -e "$target" ]]; then
      if paths_match "$source" "$target"; then
        echo "Unchanged: $target"
        return
      fi

      backup_existing_path "$target"
    fi

    cp -r "$source" "$target"
    echo "Installed: $target"
  fi
}

copy_file_if_changed() {
  local source="$1"
  local target="$2"

  if [[ ! -f "$source" ]]; then
    return
  fi

  if [[ -e "$target" ]]; then
    if paths_match "$source" "$target"; then
      echo "Unchanged: $target"
      return
    fi

    backup_existing_path "$target"
  fi

  cp "$source" "$target"
  echo "Installed: $target"
}

copy_niri_config() {
  local source="$REPO_DIR/dotfiles/niri"
  local target="$HOME/.config/niri"

  if [[ ! -d "$source" ]]; then
    return
  fi

  mkdir -p "$target"
  copy_file_if_changed "$source/config.kdl" "$target/config.kdl"

  if [[ -d "$source/kakku" ]]; then
    if [[ -e "$target/kakku" ]]; then
      if paths_match "$source/kakku" "$target/kakku"; then
        echo "Unchanged: $target/kakku"
      else
        backup_existing_path "$target/kakku"
        cp -r "$source/kakku" "$target/kakku"
        echo "Installed: $target/kakku"
      fi
    else
      cp -r "$source/kakku" "$target/kakku"
      echo "Installed: $target/kakku"
    fi
  fi
}

require_command sudo
require_command pacman

mapfile -t pacman_packages < <(
  {
    read_package_list "$REPO_DIR/packages/pacman.txt"

    if [[ -d "$REPO_DIR/packages/profiles" ]]; then
      for package_file in "$REPO_DIR"/packages/profiles/*.txt; do
        [[ -f "$package_file" ]] || continue
        read_package_list "$package_file"
      done
    fi
  } | awk '!seen[$0]++'
)
install_pacman_packages() {
  if (( ${#pacman_packages[@]} > 0 )); then
    sudo pacman "${pacman_flags[@]}" "${pacman_packages[@]}"
  fi
}

install_pacman_packages

install_aur_packages() {
  mapfile -t aur_packages < <(read_package_list "$REPO_DIR/packages/aur.txt")
  if (( ${#aur_packages[@]} == 0 )); then
    return
  fi

  # Prefer paru, fall back to yay if available.
  local aur_cmd=""
  local package
  local -a failed_packages=()
  for helper in paru yay; do
    if has_command "$helper"; then
      aur_cmd="$helper"
      break
    fi
  done

  if [[ -n "$aur_cmd" ]]; then
    for package in "${aur_packages[@]}"; do
      if ! "$aur_cmd" "${aur_helper_flags[@]}" "$package"; then
        echo "Warning: failed to install AUR package, continuing: $package" >&2
        failed_packages+=("$package")
      fi
    done

    if (( ${#failed_packages[@]} > 0 )); then
      echo "Warning: skipped failed AUR packages: ${failed_packages[*]}" >&2
    fi
  else
    echo "AUR packages are listed, but neither paru nor yay is installed." >&2
    echo "Install one AUR helper, then run the AUR install manually:" >&2
    echo "  paru -S --needed - < packages/aur.txt" >&2
  fi
}

install_aur_packages

mkdir -p "$HOME/.config"

copy_config_dir fastfetch
copy_config_dir lazygit
copy_config_dir starship
copy_config_dir yazi
copy_niri_config
copy_config_dir nvim

if has_command xdg-user-dirs-update; then
  xdg-user-dirs-update || true
fi

mkdir -p "$HOME/Pictures/Screenshots"

if [[ -d "$REPO_DIR/branding" ]]; then
  sudo install -dm755 /usr/share/kakku/branding
  sudo cp -r "$REPO_DIR/branding/." /usr/share/kakku/branding/
fi

if [[ -f "$REPO_DIR/branding/wallpaper.png" ]]; then
  sudo install -Dm644 "$REPO_DIR/branding/wallpaper.png" /usr/share/backgrounds/kakku/wallpaper.png
fi

if [[ -d "$REPO_DIR/backgrounds" ]]; then
  sudo install -dm755 /usr/share/backgrounds/kakku
  sudo cp -r "$REPO_DIR/backgrounds/." /usr/share/backgrounds/kakku/
fi

if [[ -d "$REPO_DIR/system/browser" ]]; then
  sudo install -dm755 /usr/share/kakku/browser
  sudo cp -r "$REPO_DIR/system/browser/." /usr/share/kakku/browser/
fi

if [[ -d "$REPO_DIR/system/dms" ]]; then
  sudo install -dm755 /usr/share/kakku/dms
  sudo cp -r "$REPO_DIR/system/dms/." /usr/share/kakku/dms/
fi

if [[ -d "$REPO_DIR/system/screensaver" ]]; then
  sudo install -dm755 /usr/share/kakku/screensaver
  sudo cp -r "$REPO_DIR/system/screensaver/." /usr/share/kakku/screensaver/
fi

if [[ -d "$REPO_DIR/bin" ]]; then
  for script in "$REPO_DIR"/bin/kakku*; do
    [[ -f "$script" ]] || continue
    sudo install -Dm755 "$script" "/usr/bin/$(basename "$script")"
  done
fi

if [[ -f "$REPO_DIR/system/pacman.d/hooks/kakku-browser-policies.hook" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/pacman.d/hooks/kakku-browser-policies.hook" /usr/share/libalpm/hooks/kakku-browser-policies.hook
fi

if [[ -f "$REPO_DIR/system/xdg-desktop-portal/niri-portals.conf" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/xdg-desktop-portal/niri-portals.conf" /usr/share/xdg-desktop-portal/niri-portals.conf
fi

if [[ -x "$REPO_DIR/bin/kakku-browser-policies" ]]; then
  KAKKU_BROWSER_POLICIES_SOURCE="$REPO_DIR/system/browser/policies.json" "$REPO_DIR/bin/kakku-browser-policies" || true
fi

if [[ "${KAKKU_INSTALL_DMS_PLUGINS:-1}" == "1" && -x "$REPO_DIR/bin/kakku-dms-plugins" ]]; then
  KAKKU_DMS_PLUGIN_DEFAULTS="$REPO_DIR/system/dms/plugin_settings.defaults.json" \
    KAKKU_DMS_SETTINGS_DEFAULTS="$REPO_DIR/system/dms/settings.defaults.json" \
    "$REPO_DIR/bin/kakku-dms-plugins" --no-restart || true
fi

if has_command xdg-mime && has_command kakku-defaults; then
  kakku-defaults || true
fi

# Disable CachyOS welcome app autostart.
if [[ -f /etc/xdg/autostart/cachyos-hello.desktop ]]; then
  sudo rm -f /etc/xdg/autostart/cachyos-hello.desktop
fi
if [[ -f "$HOME/.config/autostart/cachyos-hello.desktop" ]]; then
  rm -f "$HOME/.config/autostart/cachyos-hello.desktop"
fi

copy_file_if_changed "$REPO_DIR/dotfiles/bash/.bashrc" "$HOME/.bashrc"
copy_file_if_changed "$REPO_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
copy_config_dir fish

if has_command fish; then
  chsh -s /usr/bin/fish "$USER" || true
fi

if [[ "$KAKKU_SYSTEM_CONFIG" == "1" ]]; then
  if has_command kakku-disable-plymouth; then
    sudo kakku-disable-plymouth
  fi

  if [[ -f "$REPO_DIR/system/environment.d/kakku.conf" ]]; then
    sudo install -Dm644 "$REPO_DIR/system/environment.d/kakku.conf" /etc/environment.d/kakku.conf
  fi

  if [[ -f "$REPO_DIR/system/default/limine" ]]; then
    sudo install -Dm644 "$REPO_DIR/system/default/limine" /usr/share/kakku/default/limine
  fi

  if [[ -x "$REPO_DIR/bin/kakku-limine-defaults" ]]; then
    sudo KAKKU_LIMINE_DEFAULTS_SOURCE="$REPO_DIR/system/default/limine" "$REPO_DIR/bin/kakku-limine-defaults"
  elif has_command kakku-limine-defaults; then
    sudo KAKKU_LIMINE_DEFAULTS_SOURCE="$REPO_DIR/system/default/limine" kakku-limine-defaults
  fi

  if [[ -f "$REPO_DIR/system/systemd/user/kakku-idle.service" ]]; then
    sudo install -Dm644 "$REPO_DIR/system/systemd/user/kakku-idle.service" /usr/lib/systemd/user/kakku-idle.service
    sudo systemctl --global enable kakku-idle.service || true
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now kakku-idle.service 2>/dev/null || true
    systemctl --user enable --now dsearch.service 2>/dev/null || true
  fi

  sudo systemctl enable NetworkManager || true
  sudo systemctl enable bluetooth || true
  sudo systemctl enable docker || true
  sudo systemctl enable tailscaled || true
  sudo systemctl enable ananicy-cpp || true
  sudo systemctl enable power-profiles-daemon || true
  if [[ -x "$REPO_DIR/bin/kakku-firewall-defaults" ]]; then
    sudo "$REPO_DIR/bin/kakku-firewall-defaults" || true
  elif has_command kakku-firewall-defaults; then
    sudo kakku-firewall-defaults || true
  fi
  sudo usermod -aG docker "$USER" || true

  # Set up DMS greeter as login manager UI.
  if has_command dms; then
    DMS_PRIVESC="${DMS_PRIVESC:-sudo}" dms greeter install --yes || true
    DMS_PRIVESC="${DMS_PRIVESC:-sudo}" dms greeter enable --yes || true
    DMS_PRIVESC="${DMS_PRIVESC:-sudo}" dms greeter sync --yes || true
  fi
  sudo install -Dm644 "$REPO_DIR/system/greetd/config.toml" /etc/greetd/config.toml
  sudo systemctl disable sddm.service 2>/dev/null || true
  sudo systemctl enable greetd.service || true

  # Override os-release with KakkuOS branding
  if [[ -f "$REPO_DIR/system/os-release" ]]; then
    sudo cp "$REPO_DIR/system/os-release" /usr/lib/os-release
  fi

else
  echo "Skipped KakkuOS system configuration because --no-system-config was set."
fi

echo ""
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║               Kakku setup complete!             ║"
echo "  ║                                                 ║"
echo "  ║  A reboot is recommended to apply all changes.  ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo ""
