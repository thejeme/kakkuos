#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Non-interactive installs are the default. Set `KAKKU_NONINTERACTIVE=0` to
# run interactively. When non-interactive, add `--noconfirm` to pacman/AUR
# helper flags so the script doesn't pause for user confirmation.
KAKKU_NONINTERACTIVE="${KAKKU_NONINTERACTIVE:-1}"
SUDO_KEEPALIVE_PID=""

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

target_login_user() {
  printf '%s\n' "${KAKKU_TARGET_USER:-${SUDO_USER:-$USER}}"
}

set_fish_login_shell() {
  local fish_path=""
  local target_user=""

  fish_path="$(command -v fish 2>/dev/null || true)"
  target_user="$(target_login_user)"

  if [[ -z "$fish_path" || ! -x "$fish_path" ]]; then
    echo "Warning: skipped login shell change; fish is unavailable." >&2
    return 0
  fi

  if ! "$fish_path" --no-config -c 'exit 0'; then
    echo "Warning: skipped login shell change; fish did not pass a launch check." >&2
    return 0
  fi

  if [[ -z "$target_user" ]] || ! id "$target_user" >/dev/null 2>&1; then
    echo "Warning: skipped login shell change; unknown user: ${target_user:-unset}" >&2
    return 0
  fi

  if [[ -f /etc/shells ]] && ! grep -Fxq "$fish_path" /etc/shells; then
    printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null
  fi

  sudo usermod -s "$fish_path" "$target_user"
  echo "Set login shell for $target_user to $fish_path"
}

enable_greetd_login_manager() {
  local config_source="$REPO_DIR/system/greetd/config.toml"

  for command_name in greetd dms-greeter niri; do
    if ! has_command "$command_name"; then
      echo "Warning: skipped greetd switch; missing command: $command_name" >&2
      return 0
    fi
  done

  if [[ ! -d /usr/share/quickshell/dms ]]; then
    echo "Warning: skipped greetd switch; missing DMS shell path: /usr/share/quickshell/dms" >&2
    return 0
  fi

  if ! id greeter >/dev/null 2>&1; then
    echo "Warning: skipped greetd switch; greeter user is missing." >&2
    return 0
  fi

  sudo install -Dm644 "$config_source" /etc/greetd/config.toml
  sudo systemctl disable sddm.service 2>/dev/null || true
  sudo systemctl disable ly.service 2>/dev/null || true
  sudo systemctl enable greetd.service || true
  echo "Enabled greetd login manager."
}

if [[ "$#" -gt 0 ]]; then
  die "install.sh does not accept command-line options."
fi

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

copy_config_dir() {
  local name="$1"
  local source="$REPO_DIR/dotfiles/$name"
  local target="$HOME/.config/$name"
  local source_path=""
  local relative_path=""
  local target_path=""

  if [[ -d "$source" ]]; then
    mkdir -p "$target"

    while IFS= read -r -d '' source_path; do
      relative_path="${source_path#$source/}"
      target_path="$target/$relative_path"

      mkdir -p "$(dirname "$target_path")"
      cp -a "$source_path" "$target_path"
      echo "Installed: $target_path"
    done < <(find "$source" -type f -print0)
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
  fi

  mkdir -p "$(dirname "$target")"
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
    copy_config_dir niri/kakku
  fi
}

require_command sudo
require_command pacman

start_sudo_keepalive() {
  sudo -v

  while true; do
    sleep 60
    sudo -n true 2>/dev/null || exit
  done &
  SUDO_KEEPALIVE_PID="$!"
}

stop_sudo_keepalive() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}

trap stop_sudo_keepalive EXIT
start_sudo_keepalive

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

# Remove CachyOS packages that conflict with or are replaced by KakkuOS.
cachyos_remove=(
  cachyos-hello
  cachyos-wallpapers
  cachyos-fish-config
  cachyos-zsh-config
)
cachyos_installed=()
for pkg in "${cachyos_remove[@]}"; do
  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    cachyos_installed+=("$pkg")
  fi
done
if (( ${#cachyos_installed[@]} > 0 )); then
  sudo pacman -Rns --noconfirm "${cachyos_installed[@]}" || true
fi

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

if [[ -f "$REPO_DIR/system/xdg-desktop-portal/niri-portals.conf" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/xdg-desktop-portal/niri-portals.conf" /usr/share/xdg-desktop-portal/niri-portals.conf
fi

if [[ -x "$REPO_DIR/bin/kakku-browser-policies" ]]; then
  KAKKU_BROWSER_POLICIES_SOURCE="$REPO_DIR/system/browser/policies.json" "$REPO_DIR/bin/kakku-browser-policies" || true
fi

if has_command xdg-mime && has_command kakku-defaults; then
  kakku-defaults || true
fi

copy_file_if_changed "$REPO_DIR/dotfiles/bash/.bashrc" "$HOME/.bashrc"
copy_file_if_changed "$REPO_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
copy_config_dir fish

set_fish_login_shell

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

target_user="$(target_login_user)"
if [[ -n "$target_user" ]] && id "$target_user" >/dev/null 2>&1; then
  sudo usermod -aG docker "$target_user" || true
fi

enable_greetd_login_manager

# Override os-release with KakkuOS branding
if [[ -f "$REPO_DIR/system/os-release" ]]; then
  sudo cp "$REPO_DIR/system/os-release" /usr/lib/os-release
fi

echo ""
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║               Kakku setup complete!             ║"
echo "  ║                                                 ║"
echo "  ║  A reboot is recommended to apply all changes.  ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo ""
