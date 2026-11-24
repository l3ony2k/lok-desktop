#!/usr/bin/env bash
# Keep the machine's non-dots customisations in this repo (asus/home/ mirrors $HOME).
#   home-sync.sh pull     copy the listed files from $HOME into asus/home/   (then review + commit)
#   home-sync.sh diff     show which listed files differ between $HOME and the repo
#   home-sync.sh restore  copy asus/home/ back into $HOME (backs up what it overwrites first)
# Dots-owned files (dots/.config/...) are NOT listed here: they live in dots/ and are installed by setup.
# Never listed: ~/.ssh, *.env, ~/.config/mihomo/sub-url and /etc/mihomo (subscription), binaries/AppImages, *.bak.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); STORE="$HERE/home"
cd "$HOME"

MANIFEST=(
  # Files that programs rewrite themselves, so they are COPIED (pull/restore), not symlinked.
  # Hand-edited configs are symlinked by asus/links.sh instead -- don't list them here too.
  # ii runtime config (ii rewrites it on every settings change)
  .config/illogical-impulse/config.json .config/system-fonts/config.json
  .local/share/claude/hibernate-fix/apply.sh .local/share/claude/hibernate-fix/verify.sh
  # KDE Plasma session: KWin, shortcuts, input, power, lock, wallet -> Secret Service, panel layout
  .config/kwinrc .config/kglobalshortcutsrc .config/kcminputrc .config/kscreenlockerrc .config/plasmarc
  .config/powerdevilrc .config/kwalletrc .config/kwinoutputconfig.json .config/plasma-org.kde.plasma.desktop-appletsrc
  .config/plasma-workspace/env .config/plasma-workspace/shutdown .config/autostart/plasma-wallpaper-sync.desktop
  .local/share/plasma/plasmoids/local.iicontrols
  .local/share/plasma/desktoptheme/lok .local/share/aurorae/themes/lok-dark .local/share/aurorae/themes/lok-light
  .local/share/color-schemes/LokDark.colors .local/share/color-schemes/LokLight.colors
  # three-finger drag (Plasma only) + the patched AUR package sources
  .config/linux-3-finger-drag .config/systemd/user/three-finger-drag-plasma.service
  .local/src/aur-local/linux-3-finger-drag-git
  # input method: fcitx5 writes these itself
  .config/fcitx5/conf .config/fcitx5/profile
  # apps: flags, launchers, toolkit settings
  .config/brave-origin-flags.conf .config/spotify-launcher.conf .config/gtk-2.0/gtkrc .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini
  .local/share/applications/onekey-wallet.desktop
  .local/share/applications/workflowy.desktop .local/share/workflowy-nomenu/launch.sh
  # herdr: app-written settings/keys/layouts (its *-flat mods and themes are symlinked)
  .config/herdr-app/settings.json .config/herdr-app/keys.json .config/herdr-app/layouts
  .config/systemd/user/herdr-end4-theme.path .config/systemd/user/herdr-end4-theme.service
  .config/systemd/user/sleep-lock-delay.service .config/systemd/user/vibe-usage.service
  # fonts not shipped by a package (Ioskeley Mono is downloaded by asus/install.sh instead: 90 MB)
  .local/share/fonts/lok-icons .local/share/fonts/paper-mono-nerd-font
)


case "${1:-}" in
  pull)
    for p in "${MANIFEST[@]}"; do
      [ -e "$p" ] || { echo "missing: ~/$p"; continue; }
      mkdir -p "$STORE/$(dirname "$p")"
      rsync -a --delete --exclude '*.bak*' --exclude '__pycache__' --exclude '*.d.ts' --exclude node_modules --exclude cached_layouts --exclude .state "$p" "$STORE/$(dirname "$p")/"
    done
    # package lists for asus/install.sh (local builds and end-4's own meta packages excluded)
    mkdir -p "$HERE/packages"
    pacman -Qqen > "$HERE/packages/pacman.txt"
    pacman -Qqem | grep -vE '^(illogical-impulse-.*|.*-debug|yay-bin|rust-fp-.*-local|linux-3-finger-drag-git)$' > "$HERE/packages/aur.txt"
    echo "pulled into $STORE -- review with git diff, then commit" ;;
  diff)
    for p in "${MANIFEST[@]}"; do
      [ -e "$p" ] || { echo "missing on machine: ~/$p"; continue; }
      [ -e "$STORE/$p" ] || { echo "not in repo: ~/$p"; continue; }
      if [ -d "$p" ]; then diff -rq -x '*.bak*' -x __pycache__ -x '*.d.ts' -x node_modules -x cached_layouts -x .state "$p" "$STORE/$p" >/dev/null || echo "differs: ~/$p/"
      else
        cmp -s "$p" "$STORE/$p" || echo "differs: ~/$p"
      fi
    done ;;
  restore)
    bk="$HOME/.local/state/home-sync/restore-$(date +%Y%m%d-%H%M%S).tar.gz"; mkdir -p "$(dirname "$bk")"
    tar -czf "$bk" --ignore-failed-read "${MANIFEST[@]}" 2>/dev/null || true
    echo "backup of current files: $bk"
    # only the MANIFEST entries: asus/home/ also holds the symlink targets of links.sh,
    # which must not be copied over their links
    for p in "${MANIFEST[@]}"; do
      [ -e "$STORE/$p" ] || continue
      mkdir -p "$(dirname "$p")"; rsync -a "$STORE/$p" "$(dirname "$p")/"
    done
    echo "restored. Re-login for Plasma/env changes." ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
