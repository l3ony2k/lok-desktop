#!/usr/bin/env bash
# asus/install.sh — rebuild this machine's setup on a fresh Arch install, stage by stage.
# Read asus/RESTORE.md first; it says what has to exist before each stage and what stays manual.
#
#   asus/install.sh <stage>     run one stage        asus/install.sh all   run them in order
#   asus/install.sh list        show the stages
#
# Every stage is safe to re-run (it skips what is already done). Nothing here touches
# /etc, the bootloader or the disk layout; `system` only shows the diff (see RESTORE.md).
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
A=$REPO/asus
cd "$REPO"
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

st_packages() {
  say "packages: official repos (asus/packages/pacman.txt)"
  sudo pacman -S --needed - < "$A/packages/pacman.txt"
  say "packages: AUR (asus/packages/aur.txt) via yay"
  if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d); git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  fi
  yay -S --needed - < "$A/packages/aur.txt"
  echo "Local packages (not on AUR) are built from this repo by hand -- see RESTORE.md 'Local builds'."
}

st_end4() {
  say "end-4 illogical-impulse: dependencies + services, and the dots files (first install only)"
  # First install: let end-4 copy every dots file (the ones we symlink are replaced by `links` next).
  # Later runs must never copy files over the symlinks again, so they skip that step.
  if [ -L "$HOME/.config/quickshell/ii" ]; then
    ./setup install --skip-allfiles
  else
    ./setup install
  fi
}

st_home() {
  say "home: copy the program-written configs (asus/home-sync.sh restore)"
  bash "$A/home-sync.sh" restore
}

st_links() {
  say "links: symlink the hand-edited configs into \$HOME (asus/links.sh)"
  bash "$A/links.sh" apply
}

st_fonts() {
  say "fonts: Ioskeley Mono Term Nerd Font (kitty), downloaded from its GitHub release"
  d="$HOME/.local/share/fonts/ioskeley-term-nf"
  if ls "$d"/*.ttf >/dev/null 2>&1; then echo "already installed"; else
    tmp=$(mktemp -d)
    curl -fL -o "$tmp/f.zip" https://github.com/ahatem/IoskeleyMono/releases/latest/download/IoskeleyMono-Term-NerdFont.zip
    mkdir -p "$d"; bsdtar -xf "$tmp/f.zip" -C "$tmp"
    find "$tmp" -path '*Normal*' -name 'IoskeleyMonoTermNerdFont-*.ttf' -exec cp {} "$d/" \;
    rm -rf "$tmp"
  fi
  fc-cache -f >/dev/null && echo "font cache rebuilt"
}

st_services() {
  say "services: user units"
  systemctl --user daemon-reload
  for u in sleep-lock-delay.service vibe-usage.service; do
    [ -f "$HOME/.config/systemd/user/$u" ] && systemctl --user enable --now "$u" || true
  done
  say "services: system units this machine enables (only those whose package is installed)"
  for u in bluetooth greetd keyd mihomo NetworkManager power-profiles-daemon sshd tailscaled ufw \
           battery-charge-threshold fan-mode-reset rust-fp-dbus-interface; do
    systemctl list-unit-files "$u.service" --no-legend | grep -q . && sudo systemctl enable "$u.service" || echo "  skip $u (not installed yet)"
  done
}

st_system() {
  say "system: compare asus/system/ with / (nothing is written)"
  bash "$A/system-diff.sh"
  echo "Copy what you need by hand -- RESTORE.md 'System files' lists which are machine-specific."
}

STAGES=(packages end4 home links fonts services system)
case "${1:-list}" in
  list) printf '%s\n' "${STAGES[@]}" ;;
  all) for s in "${STAGES[@]}"; do "st_$s"; done ;;
  *) if declare -F "st_$1" >/dev/null; then "st_$1"; else echo "unknown stage: $1"; exit 1; fi ;;
esac
