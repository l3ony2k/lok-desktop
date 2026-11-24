#!/usr/bin/env bash
# Keep the machine's non-dots customisations in this repo (asus/home/ mirrors $HOME).
#   home-sync.sh pull     copy the listed files from $HOME into asus/home/   (then review + commit)
#   home-sync.sh diff     show which listed files differ between $HOME and the repo
#   home-sync.sh restore  copy asus/home/ back into $HOME (backs up what it overwrites first)
# Dots-owned files (dots/.config/...) are NOT listed here: they live in dots/ and are installed by setup.
# Never listed: ~/.ssh, *.env, /etc/mihomo (subscription), binaries/AppImages, *.bak.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); STORE="$HERE/home"
cd "$HOME"

MANIFEST=(
  # dashboard helpers
  .local/bin/top-apps
  .local/bin/ii-restart
  # shell
  .zshenv .zshrc.local .zprofile .p10k.zsh .bashrc .bash_profile
  .config/fish/functions/qs.fish .config/fish/conf.d/nvm.fish
  # (.zshrc and fastfetch/config.jsonc are symlinks into the separate dotfiles repo)
  # ii runtime config, ii customisation scripts, hyprlock wrapper, helper scripts
  .config/illogical-impulse/config.json .local/share/ii-customizations
  .local/bin/hyprlock .local/bin/ii-lock-park .local/bin/ii-net-tiles-customize .local/bin/ii-rounding-customize
  .local/bin/system-font .local/bin/watch-hypr-fullscreen-color.sh .local/bin/dots-cleanup.sh
  .local/bin/mihomo-update-sub
  .config/hypr/custom/scripts .config/system-fonts/config.json
  .local/share/claude/hibernate-fix/apply.sh .local/share/claude/hibernate-fix/verify.sh
  .config/orca/linux-orca-cli-shim/orca
  # KDE Plasma session: KWin, shortcuts, input, power, lock, wallet -> Secret Service, panel layout
  .config/kwinrc .config/kglobalshortcutsrc .config/kcminputrc .config/kscreenlockerrc .config/plasmarc
  .config/powerdevilrc .config/kwalletrc .config/kwinoutputconfig.json .config/plasma-org.kde.plasma.desktop-appletsrc
  .config/plasma-workspace/env .config/plasma-workspace/shutdown .config/autostart/plasma-wallpaper-sync.desktop
  .local/bin/plasma-coffee .local/bin/plasma-wallpaper-sync
  .local/share/plasma/plasmoids/local.iicontrols
  .local/share/plasma/desktoptheme/lok .local/share/aurorae/themes/lok-dark .local/share/aurorae/themes/lok-light
  .local/share/color-schemes/LokDark.colors .local/share/color-schemes/LokLight.colors
  # three-finger drag (Plasma only) + the patched AUR package
  .config/linux-3-finger-drag .config/systemd/user/three-finger-drag-plasma.service
  src/aur-local/linux-3-finger-drag-git/PKGBUILD src/aur-local/linux-3-finger-drag-git/3fd-tap-candidate.patch
  src/aur-local/linux-3-finger-drag-git/linux-3-finger-drag-git.install src/aur-local/linux-3-finger-drag-git/three-finger-drag.service
  src/aur-local/linux-3-finger-drag-git/80-linux-3-finger-drag.rules src/aur-local/linux-3-finger-drag-git/uinput.conf
  # input method: fcitx5 + rime (double pinyin flypy), candidate window theme
  .config/fcitx5/conf .config/fcitx5/profile
  .local/share/fcitx5/rime/default.custom.yaml .local/share/fcitx5/rime/double_pinyin_flypy.custom.yaml
  .local/share/fcitx5/themes/rime-material .local/share/fcitx5/themes/lok-dark .local/share/fcitx5/themes/lok-light
  # apps: Brave flags, launchers with Secret Service flags, toolkit settings
  .config/brave-origin-flags.conf .config/spotify-launcher.conf .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini
  .local/share/applications/onekey-wallet.desktop .local/share/applications/orca-ide.desktop
  .local/share/applications/workflowy.desktop .local/share/workflowy-nomenu/launch.sh
  .config/nnn/edit .config/nnn/tmux.conf
  # herdr flat theme (settings, keys, layouts, mods, themes only -- not its data)
  .config/herdr-app/settings.json .config/herdr-app/keys.json .config/herdr-app/layouts .config/herdr-app/mods/*-flat
  .config/herdr-app/themes .local/share/herdr-end4 .config/systemd/user/herdr-end4-theme.path
  .config/systemd/user/herdr-end4-theme.service
  # LibreWolf flat chrome
  .config/librewolf/librewolf/wobsi8ej.default-release/chrome/userChrome.css
  .config/librewolf/librewolf/wobsi8ej.default-release/chrome/userContent.css
)

redact() { # $1 = stored copy; strip secrets that must not enter git
  case "$1" in
    */mihomo-update-sub) sed -i -E 's|^SUB_URL=.*|SUB_URL="${MIHOMO_SUB_URL:?set MIHOMO_SUB_URL}"  # real URL kept off git|' "$1" ;;
  esac
}

case "${1:-}" in
  pull)
    for p in "${MANIFEST[@]}"; do
      [ -e "$p" ] || { echo "missing: ~/$p"; continue; }
      mkdir -p "$STORE/$(dirname "$p")"
      rsync -a --delete --exclude '*.bak*' --exclude '__pycache__' --exclude '*.d.ts' --exclude node_modules --exclude cached_layouts "$p" "$STORE/$(dirname "$p")/"
      [ -f "$STORE/$p" ] && redact "$STORE/$p"
    done
    echo "pulled into $STORE -- review with git diff, then commit" ;;
  diff)
    for p in "${MANIFEST[@]}"; do
      [ -e "$p" ] || { echo "missing on machine: ~/$p"; continue; }
      [ -e "$STORE/$p" ] || { echo "not in repo: ~/$p"; continue; }
      if [ -d "$p" ]; then diff -rq -x '*.bak*' -x __pycache__ -x '*.d.ts' -x node_modules -x cached_layouts "$p" "$STORE/$p" >/dev/null || echo "differs: ~/$p/"
      else
        case "$p" in */mihomo-update-sub) continue ;; esac   # stored copy is redacted
        cmp -s "$p" "$STORE/$p" || echo "differs: ~/$p"
      fi
    done ;;
  restore)
    bk="$HOME/snapshots/home-restore-$(date +%Y%m%d-%H%M%S).tar.gz"; mkdir -p "$HOME/snapshots"
    tar -czf "$bk" --ignore-failed-read "${MANIFEST[@]}" 2>/dev/null || true
    echo "backup of current files: $bk"
    # an existing mihomo-update-sub keeps its real URL; the redacted copy is only installed if none exists
    rsync -a --exclude '.local/bin/mihomo-update-sub' "$STORE/" "$HOME/"
    [ -e .local/bin/mihomo-update-sub ] || cp "$STORE/.local/bin/mihomo-update-sub" .local/bin/
    echo "restored. A fresh mihomo-update-sub needs MIHOMO_SUB_URL. Re-login for Plasma/env changes." ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
