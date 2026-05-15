#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
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

if (( ${#pacman_packages[@]} > 0 )); then
  sudo pacman -Syu --needed "${pacman_packages[@]}"
fi

mapfile -t aur_packages < <(read_package_list "$REPO_DIR/packages/aur.txt")

if (( ${#aur_packages[@]} > 0 )); then
  if command -v paru >/dev/null 2>&1; then
    paru -S --needed "${aur_packages[@]}"
  elif command -v yay >/dev/null 2>&1; then
    yay -S --needed "${aur_packages[@]}"
  else
    echo "AUR packages are listed, but neither paru nor yay is installed." >&2
    echo "Install one AUR helper, then run the AUR install manually:" >&2
    echo "  paru -S --needed - < packages/aur.txt" >&2
  fi
fi

mkdir -p "$HOME/.config"

copy_config_dir hypr
copy_config_dir waybar
copy_config_dir rofi
copy_config_dir alacritty
copy_config_dir fastfetch
copy_config_dir mako
copy_config_dir lazygit
copy_config_dir yazi
copy_config_dir btop

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  xdg-user-dirs-update || true
fi

mkdir -p "$HOME/Pictures/Screenshots"

if [[ -d "$REPO_DIR/branding" ]]; then
  sudo install -dm755 /usr/share/backgrounds/kakku
  sudo cp -r "$REPO_DIR/branding/." /usr/share/backgrounds/kakku/
fi

if [[ -d "$REPO_DIR/themes" ]]; then
  sudo install -dm755 /usr/share/kakku/themes
  sudo cp -r "$REPO_DIR/themes/." /usr/share/kakku/themes/
fi

if [[ -d "$REPO_DIR/bin" ]]; then
  for script in "$REPO_DIR"/bin/kakku*; do
    [[ -f "$script" ]] || continue
    sudo install -Dm755 "$script" "/usr/bin/$(basename "$script")"
  done
fi

if command -v kakku-disable-plymouth >/dev/null 2>&1; then
  sudo kakku-disable-plymouth
fi

if command -v xdg-mime >/dev/null 2>&1 && command -v kakku-defaults >/dev/null 2>&1; then
  kakku-defaults || true
fi

if [[ -f "$REPO_DIR/system/environment.d/kakku.conf" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/environment.d/kakku.conf" /etc/environment.d/kakku.conf
fi

copy_file_if_changed "$REPO_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"

if command -v zsh >/dev/null 2>&1; then
  chsh -s /usr/bin/zsh "$USER" || true
fi

sudo systemctl enable NetworkManager || true
sudo systemctl enable bluetooth || true
sudo systemctl enable docker || true
sudo systemctl enable tailscaled || true
sudo usermod -aG docker "$USER" || true

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║               Kakku setup complete!                          ║"
echo "  ║                                                              ║"
echo "  ║  A reboot is recommended to apply all changes.               ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
