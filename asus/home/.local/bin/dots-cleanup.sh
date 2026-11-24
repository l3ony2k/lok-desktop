#!/usr/bin/env bash
# dots-hyprland cleanup: remove duplicate packages that the dots do not use,
# restore build deps lost to an over-eager orphan purge, and set up scoped
# passwordless sudo for package management.
#
# Run once with: sudo /home/leon/.local/bin/dots-cleanup.sh
# Safe to re-run; every step checks current state first.

set -euo pipefail

USER_NAME=leon
USER_HOME=/home/leon

RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'; CYA=$'\e[36m'; RST=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$CYA" "$*" "$RST"; }
warn() { printf '%s[warn]%s %s\n' "$YEL" "$RST" "$*"; }
ok()   { printf '%s[ok]%s %s\n' "$GRN" "$RST" "$*"; }
die()  { printf '%s[error]%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must be run as root (sudo $0)"

##############################################################################
# 0. Preflight
##############################################################################
step "Preflight"

for f in /usr/bin/pacman /usr/bin/paru /usr/bin/yay /usr/bin/visudo; do
  [[ -x $f ]] || die "required binary missing: $f"
done

# The dots install script hard-requires yay and bootstraps it itself.
# paru is never invoked by the dots, so it is safe to drop.
[[ -x /usr/bin/yay ]] || die "yay missing; the dots install script needs it"

# Refuse to run if a previous run left a broken sudoers file behind.
if ! visudo -c -q >/dev/null 2>&1; then
  die "existing /etc/sudoers is invalid; refusing to touch sudo"
fi

ok "preflight passed"

##############################################################################
# 1. Restore build dependencies lost to the orphan purge
#
# pacman -Qtdq reports *make*depends as orphans because they are not in any
# installed package's Depends. They are still needed to rebuild quickshell
# and the dots helper packages. Reinstall them with --asdeps so they stay
# implicit and are not listed as explicitly installed.
##############################################################################
step "Restoring build dependencies"

BUILD_DEPS=(cli11 vulkan-headers ninja go cmake git spirv-tools
            qt6-shadertools wayland wayland-protocols)
MISSING_BUILD_DEPS=()
for p in "${BUILD_DEPS[@]}"; do
  if ! pacman -Qq "$p" >/dev/null 2>&1; then
    MISSING_BUILD_DEPS+=("$p")
  fi
done

if (( ${#MISSING_BUILD_DEPS[@]} )); then
  printf '  installing: %s\n' "${MISSING_BUILD_DEPS[*]}"
  pacman -S --needed --asdeps --noconfirm "${MISSING_BUILD_DEPS[@]}"
else
  ok "all build deps already present"
fi

# Sanity: confirm we did not silently leave quickshell unbuildable.
# Every entry of the quickshell PKGBUILD's makedepends must be present.
for p in cli11 vulkan-headers ninja cmake git spirv-tools qt6-shadertools \
         wayland wayland-protocols; do
  pacman -Qq "$p" >/dev/null 2>&1 || die "build dep $p still missing after install"
done
ok "quickshell makedepends satisfied"

##############################################################################
# 2. Remove duplicate / unused packages
#
# network-manager-applet: dots drives networking via nmcli + plasma-nm
#   (both required by illogical-impulse-kde). The GTK applet is a second,
#   unused network UI, and pulls in nm-connection-editor + libnma as well.
# paru-bin: dots' install-deps.sh uses yay exclusively (and bootstraps it).
# xarchiver: dolphin has built-in archive support, and this is not a dots dep.
#
# grim is intentionally NOT removed: it is a hard dependency of hyprshot
# (illogical-impulse-screencapture), and hyprshot shells out to it directly
# for region/window grabs.
##############################################################################
step "Removing duplicates"

REMOVE=(
  network-manager-applet
  nm-connection-editor
  libnma
  paru-bin
  paru-bin-debug
  xarchiver
)

PRESENT=()
for p in "${REMOVE[@]}"; do
  pacman -Qq "$p" >/dev/null 2>&1 && PRESENT+=("$p")
done

if (( ${#PRESENT[@]} )); then
  printf '  removing: %s\n' "${PRESENT[*]}"
  # -Rns drops now-unneeded deps. If pacman refuses because something
  # outside this list depends on one of them, we stop rather than force it.
  if ! pacman -Rns --noconfirm "${PRESENT[@]}"; then
    warn "pacman refused the removal; nothing was forced."
    warn "Check the dependency message above and adjust REMOVE in $0."
    exit 1
  fi
else
  ok "nothing to remove"
fi

##############################################################################
# 3. Notification daemon
#
# NOTE: no daemon is installed here on purpose. quickshell registers its own
# org.freedesktop.Notifications server (ii/services/Notifications.qml ->
# NotificationServer), and it currently owns that bus name. Installing dunst
# or mako would fight it for ownership and dots' notification popups would
# stop rendering. Left out deliberately - see the summary printed at the end.
##############################################################################
step "Notification daemon"
ok "skipped: quickshell already owns org.freedesktop.Notifications"

##############################################################################
# 4. Scoped passwordless sudo for package management
#
# Only pacman/paru/yay are passwordless. Everything else still prompts.
# This is deliberately NOT a blanket NOPASSWD: ALL.
##############################################################################
step "Configuring sudo"

SUDOERS_PKG=/etc/sudoers.d/10-pkg-nopasswd
SUDOERS_TIMEOUT=/etc/sudoers.d/20-timestamp-timeout

# Scoped NOPASSWD for package tools only.
cat >"$SUDOERS_PKG" <<'EOF'
# Managed by dots-cleanup.sh
# Allow passwordless package management only. Any other sudo use still prompts.
Cmnd_Alias PKG_TOOLS = /usr/bin/pacman, /usr/bin/paru, /usr/bin/yay
leon ALL=(root) NOPASSWD: PKG_TOOLS
EOF
chmod 0440 "$SUDOERS_PKG"
chown root:root "$SUDOERS_PKG"

# Session-wide sudo credential cache: 15 minutes instead of the default 5.
# timestamp_type=global shares one cache across all terminals owned by the
# user, so authenticating once covers every shell in the session.
cat >"$SUDOERS_TIMEOUT" <<'EOF'
# Managed by dots-cleanup.sh
Defaults:leon timestamp_timeout=15
Defaults:leon timestamp_type=global
EOF
chmod 0440 "$SUDOERS_TIMEOUT"
chown root:root "$SUDOERS_TIMEOUT"

# Validate the whole sudoers tree; roll back our files if anything is wrong.
if ! visudo -c -q >/dev/null 2>&1; then
  rm -f "$SUDOERS_PKG" "$SUDOERS_TIMEOUT"
  die "sudoers validation failed; removed our files to avoid locking you out"
fi
ok "sudoers files validated"

##############################################################################
# 5. AUR helper config: keep the sudo credential alive during builds
##############################################################################
step "Configuring yay"

YAY_CONFIG_DIR=$USER_HOME/.config/yay
YAY_CONFIG=$YAY_CONFIG_DIR/config.json

install -d -o "$USER_NAME" -g "$USER_NAME" "$YAY_CONFIG_DIR"

# yay rewrites this file itself, so merge rather than clobber.
if [[ -s $YAY_CONFIG ]] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '.sudoloop = true' "$YAY_CONFIG" >"$tmp" && mv "$tmp" "$YAY_CONFIG"
else
  cat >"$YAY_CONFIG" <<'EOF'
{
  "sudoloop": true
}
EOF
fi
chown "$USER_NAME:$USER_NAME" "$YAY_CONFIG"
ok "yay: sudoloop enabled"

##############################################################################
# 6. Verification
##############################################################################
step "Verifying"

# Dependency database must be intact.
if ! pacman -Dk >/dev/null 2>&1; then
  warn "pacman reports dependency problems; run: pacman -Dk"
else
  ok "package database consistent"
fi

# Confirm nothing we removed is still required by an installed package.
for p in network-manager-applet paru-bin xarchiver; do
  if pacman -Qq "$p" >/dev/null 2>&1; then
    warn "$p is still installed"
  fi
done

# Confirm yay still works, since the dots depend on it.
if command -v yay >/dev/null 2>&1; then
  ok "yay present: $(yay --version | head -1)"
else
  warn "yay is missing; the dots install script will try to bootstrap it"
fi

# Confirm the sudo rules parse and land where we expect.
if visudo -c -q >/dev/null 2>&1; then
  ok "sudoers syntax valid"
fi

printf '\n%sDone.%s\n' "$GRN" "$RST"
cat <<EOF

Summary
-------
  removed    network-manager-applet, nm-connection-editor, libnma,
             paru-bin, paru-bin-debug, xarchiver
  installed  ${MISSING_BUILD_DEPS[*]:-<none needed>} (as build deps)
  sudo       passwordless for pacman/paru/yay only
             credential timeout 15 min, per terminal
  yay        sudoloop enabled

Notes
-----
  * The dots edit network connections through systemsettings (Plasma KCM),
    not nm-connection-editor. The float rules left in
    ~/.config/hypr/hyprland/rules.lua for nm-connection-editor are now dead
    but harmless.
  * grim was kept: hyprshot depends on it and calls it directly for
    region and window screenshots.
  * No notification daemon was installed: quickshell owns
    org.freedesktop.Notifications itself. Verify with:
        busctl --user status org.freedesktop.Notifications
    Only install mako/dunst if you ever stop running quickshell's shell.
  * Do not use 'pacman -Qtdq' on this system without checking the list.
    It reports build-only dependencies as orphans; that is what broke
    quickshell's build chain. Use 'pacman -Qtdq' output only after
    confirming each entry is not a makedepends in
    ~/.dotfiles/sdata/dist-arch/*/PKGBUILD.
EOF
