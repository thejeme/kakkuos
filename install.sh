#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Non-interactive installs are the default. Set `KAKKU_NONINTERACTIVE=0` to
# run interactively. When non-interactive, add `--noconfirm` to pacman/AUR
# helper flags so the script doesn't pause for user confirmation.
KAKKU_NONINTERACTIVE="${KAKKU_NONINTERACTIVE:-1}"

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

require_user_invocation() {
  if (( EUID == 0 )); then
    die "Run this installer as the target desktop user, not with sudo. Use: ./install.sh"
  fi
}

require_repo_layout() {
  local path
  local -a required_paths=(
    "$REPO_DIR/packages/profiles/core.txt"
    "$REPO_DIR/packages/profiles/desktop.txt"
    "$REPO_DIR/packages/profiles/cli.txt"
    "$REPO_DIR/packages/aur.txt"
    "$REPO_DIR/dotfiles/niri/config.kdl"
    "$REPO_DIR/dotfiles/fish/config.fish"
    "$REPO_DIR/system/greetd/config.toml"
    "$REPO_DIR/system/dms/settings.defaults.json"
    "$REPO_DIR/system/default/limine"
    "$REPO_DIR/bin/kakku"
  )

  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      die "Installer source is incomplete; missing: $path"
    fi
  done
}

target_login_user() {
  printf '%s\n' "${KAKKU_TARGET_USER:-$(id -un)}"
}

require_target_user_matches_invocation() {
  local current_user
  local target_user

  current_user="$(id -un)"
  target_user="$(target_login_user)"

  if [[ "$target_user" != "$current_user" ]]; then
    die "Run this installer while logged in as $target_user; current user is $current_user."
  fi
}

set_fish_login_shell() {
  local fish_path=""
  local target_user=""

  fish_path="$(command -v fish 2>/dev/null || true)"
  target_user="$(target_login_user)"

  if [[ -z "$fish_path" || ! -x "$fish_path" ]]; then
    die "fish is unavailable; cannot set the Kakku login shell."
  fi

  if ! "$fish_path" --no-config -c 'exit 0'; then
    die "fish failed its launch check; refusing to set it as the login shell."
  fi

  if [[ -z "$target_user" ]] || ! id "$target_user" >/dev/null 2>&1; then
    die "Unknown target user for login shell: ${target_user:-unset}"
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
      die "Missing required command for greetd login: $command_name"
    fi
  done

  if [[ ! -d /usr/share/quickshell/dms ]]; then
    die "Missing DMS shell path: /usr/share/quickshell/dms"
  fi

  if ! id greeter >/dev/null 2>&1; then
    die "Missing greeter user; cannot enable greetd safely."
  fi

  sudo install -Dm644 "$config_source" /etc/greetd/config.toml
  sudo systemctl disable sddm.service 2>/dev/null || true
  sudo systemctl disable ly.service 2>/dev/null || true
  sudo systemctl enable greetd.service
  echo "Enabled greetd login manager."
}

verify_login_setup() {
  local fish_path
  local target_user
  local login_shell

  fish_path="$(command -v fish 2>/dev/null || true)"
  target_user="$(target_login_user)"

  if ! has_command getent; then
    die "Missing required command for login verification: getent"
  fi

  login_shell="$(getent passwd "$target_user" | awk -F: '{print $7}')"

  if [[ "$login_shell" != "$fish_path" && "$login_shell" != "/bin/fish" ]]; then
    die "Login shell verification failed for $target_user: ${login_shell:-unset}"
  fi

  if ! systemctl is-enabled greetd.service >/dev/null 2>&1; then
    die "greetd.service is not enabled after install."
  fi

  if [[ ! -f /etc/greetd/config.toml ]]; then
    die "greetd config is missing after install: /etc/greetd/config.toml"
  fi
}

if [[ "$#" -gt 0 ]]; then
  die "install.sh does not accept command-line options."
fi

require_user_invocation
require_repo_layout
require_target_user_matches_invocation

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

install_dms_user_settings() {
  local source="$REPO_DIR/system/dms/settings.defaults.json"
  local target="$HOME/.config/DankMaterialShell/settings.json"

  if [[ ! -f "$source" ]]; then
    return
  fi

  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"
  echo "Installed: $target"
}

enable_user_service_if_available() {
  local service="$1"

  if [[ ! -f "/usr/lib/systemd/user/$service" && ! -f "/etc/systemd/user/$service" ]]; then
    echo "Warning: user service not found, skipping: $service" >&2
    return 0
  fi

  sudo systemctl --global enable "$service" || true
  systemctl --user enable --now "$service" 2>/dev/null || true
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
  sudo pacman -R --noconfirm "${cachyos_installed[@]}" || true
fi
hash -r
require_command fish

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
        echo "Warning: failed to install AUR package: $package" >&2
        failed_packages+=("$package")
      fi
    done

    if (( ${#failed_packages[@]} > 0 )); then
      die "Failed to install required AUR packages: ${failed_packages[*]}"
    fi
  else
    die "AUR packages are required, but neither paru nor yay is installed."
  fi
}

install_aur_packages

mkdir -p "$HOME/.config"

copy_config_dir fastfetch
copy_config_dir ghostty
copy_config_dir git
copy_config_dir lazygit
copy_config_dir mpv
copy_config_dir starship
copy_config_dir yazi
copy_config_dir zathura
copy_niri_config
copy_config_dir niri-screensaver
copy_config_dir nvim
install_dms_user_settings

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

if [[ -x "$REPO_DIR/bin/kakku-browser-theme" ]]; then
  "$REPO_DIR/bin/kakku-browser-theme" || true
fi

if [[ -x "$REPO_DIR/bin/kakku-vscode-theme" ]]; then
  "$REPO_DIR/bin/kakku-vscode-theme" || true
fi

if has_command xdg-mime && has_command kakku-defaults; then
  kakku-defaults || true
fi

copy_file_if_changed "$REPO_DIR/dotfiles/bash/.bashrc" "$HOME/.bashrc"
copy_file_if_changed "$REPO_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
copy_config_dir fish

if has_command kakku-disable-plymouth; then
  sudo kakku-disable-plymouth || echo "Warning: Plymouth disable step failed; continuing install." >&2
fi

if [[ -f "$REPO_DIR/system/environment.d/kakku.conf" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/environment.d/kakku.conf" /etc/environment.d/kakku.conf
fi

if [[ -f "$REPO_DIR/system/default/limine" ]]; then
  sudo install -Dm644 "$REPO_DIR/system/default/limine" /usr/share/kakku/default/limine
fi

if [[ -x "$REPO_DIR/bin/kakku-limine-defaults" ]]; then
  sudo KAKKU_LIMINE_DEFAULTS_SOURCE="$REPO_DIR/system/default/limine" "$REPO_DIR/bin/kakku-limine-defaults" || echo "Warning: Limine defaults step failed; continuing install." >&2
elif has_command kakku-limine-defaults; then
  sudo KAKKU_LIMINE_DEFAULTS_SOURCE="$REPO_DIR/system/default/limine" kakku-limine-defaults || echo "Warning: Limine defaults step failed; continuing install." >&2
fi

systemctl --user daemon-reload 2>/dev/null || true
enable_user_service_if_available dms.service
enable_user_service_if_available dsearch.service

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

set_fish_login_shell
enable_greetd_login_manager
verify_login_setup

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
