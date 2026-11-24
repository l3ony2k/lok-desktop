#!/usr/bin/env bash
# asus/links.sh — symlink the hand-edited configs in this repo into $HOME.
#
# Files listed here live ONLY in the repo; $HOME holds a symlink, so editing the
# live file edits the repo (git status shows it). Files that programs rewrite on
# their own (KDE rc files, ii config.json, fcitx profile, ...) can't be symlinked
# (the program would replace the link with a plain file); those are copied by
# asus/home-sync.sh instead.
#
#   links.sh status          ok / missing / not-linked / wrong-link / no-source, per entry
#   links.sh apply           create missing links. An existing real file/dir that is identical
#                            to the repo copy is moved to the backup dir first; one that differs
#                            is skipped (shown as DIFFERS) so nothing is lost.
#   links.sh apply --adopt   for DIFFERS entries, copy the live version INTO the repo first
#                            (review with git diff afterwards), then link.
#   links.sh apply --force   for DIFFERS entries, the repo wins (live copy still backed up).
#
# Backups: ~/.local/state/dotfiles-links/backup-<timestamp>/
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
H=$HOME
BK="$H/.local/state/dotfiles-links/backup-$(date +%Y%m%d-%H%M%S)"

# target (relative to ~)  |  source (relative to the repo)
LINKS=(
  # --- end-4 dots this machine edits (upstream files + our commits) ---
  ".config/quickshell/ii|dots/.config/quickshell/ii"
  ".config/hypr|dots/.config/hypr"
  ".config/kitty/kitty.conf|dots/.config/kitty/kitty.conf"
  ".config/foot/foot.ini|dots/.config/foot/foot.ini"
  ".config/fuzzel/fuzzel.ini|dots/.config/fuzzel/fuzzel.ini"
  ".config/fontconfig/fonts.conf|dots/.config/fontconfig/fonts.conf"
  ".config/matugen/config.toml|dots/.config/matugen/config.toml"
  # --- shell / git ---
  # zsh reads these from $ZDOTDIR = ~/.config/zsh (set in /etc/zsh/zshenv, see asus/system)
  ".config/zsh/.zshrc|asus/home/.config/zsh/.zshrc"
  ".config/zsh/.zshrc.local|asus/home/.config/zsh/.zshrc.local"
  ".config/zsh/.zshenv|asus/home/.config/zsh/.zshenv"
  ".config/zsh/.zprofile|asus/home/.config/zsh/.zprofile"
  ".config/zsh/.p10k.zsh|asus/home/.config/zsh/.p10k.zsh"
  ".config/environment.d/50-xdg-home.conf|asus/home/.config/environment.d/50-xdg-home.conf"
  ".config/vim/vimrc|asus/home/.config/vim/vimrc"
  ".bashrc|asus/home/.bashrc"
  ".bash_profile|asus/home/.bash_profile"
  ".profile|asus/home/.profile"
  ".config/git/config|asus/home/.config/git/config"
  ".config/nnn/edit|asus/home/.config/nnn/edit"
  ".config/nnn/tmux.conf|asus/home/.config/nnn/tmux.conf"
  ".config/fastfetch/config.jsonc|asus/home/.config/fastfetch/config.jsonc"
  # --- helper scripts ---
  ".local/bin/top-apps|asus/home/.local/bin/top-apps"
  ".local/bin/ii-restart|asus/home/.local/bin/ii-restart"
  ".local/bin/hyprlock|asus/home/.local/bin/hyprlock"
  ".local/bin/ii-lock-park|asus/home/.local/bin/ii-lock-park"
  ".local/bin/ii-net-tiles-customize|asus/home/.local/bin/ii-net-tiles-customize"
  ".local/bin/ii-rounding-customize|asus/home/.local/bin/ii-rounding-customize"
  ".local/bin/system-font|asus/home/.local/bin/system-font"
  ".local/bin/watch-hypr-fullscreen-color.sh|asus/home/.local/bin/watch-hypr-fullscreen-color.sh"
  ".local/bin/dots-cleanup.sh|asus/home/.local/bin/dots-cleanup.sh"
  ".local/bin/mihomo-update-sub|asus/home/.local/bin/mihomo-update-sub"
  ".local/bin/plasma-coffee|asus/home/.local/bin/plasma-coffee"
  ".local/bin/plasma-wallpaper-sync|asus/home/.local/bin/plasma-wallpaper-sync"
  ".local/bin/idle-suspend|asus/home/.local/bin/idle-suspend"
  ".local/bin/lid-coffee|asus/home/.local/bin/lid-coffee"
  ".local/bin/power-key-session|asus/home/.local/bin/power-key-session"
  ".local/bin/sleep-lock-delay|asus/home/.local/bin/sleep-lock-delay"
  ".local/share/ii-customizations|asus/home/.local/share/ii-customizations"
  # --- input method (hand-written rime patches and candidate themes) ---
  ".local/share/fcitx5/rime/default.custom.yaml|asus/home/.local/share/fcitx5/rime/default.custom.yaml"
  ".local/share/fcitx5/rime/double_pinyin_flypy.custom.yaml|asus/home/.local/share/fcitx5/rime/double_pinyin_flypy.custom.yaml"
  ".local/share/fcitx5/themes/lok-dark|asus/home/.local/share/fcitx5/themes/lok-dark"
  ".local/share/fcitx5/themes/lok-light|asus/home/.local/share/fcitx5/themes/lok-light"
  ".local/share/fcitx5/themes/rime-material|asus/home/.local/share/fcitx5/themes/rime-material"
  # --- herdr flat theme mods, LibreWolf chrome ---
  ".config/herdr-app/themes|asus/home/.config/herdr-app/themes"
  ".local/share/herdr-end4|asus/home/.local/share/herdr-end4"
  ".config/librewolf/librewolf/wobsi8ej.default-release/chrome/userChrome.css|asus/home/.config/librewolf/librewolf/wobsi8ej.default-release/chrome/userChrome.css"
  ".config/librewolf/librewolf/wobsi8ej.default-release/chrome/userContent.css|asus/home/.config/librewolf/librewolf/wobsi8ej.default-release/chrome/userContent.css"
)
# herdr mods: every *-flat mod dir in the repo
for d in "$REPO"/asus/home/.config/herdr-app/mods/*-flat; do
  [ -d "$d" ] && LINKS+=(".config/herdr-app/mods/${d##*/}|asus/home/.config/herdr-app/mods/${d##*/}")
done

# Files that are generated at runtime inside a linked dir; they are gitignored in the
# repo and ignored when comparing a live dir with the repo copy.
EXCL=(-x '*.bak*' -x '*.before*' -x __pycache__ -x .qmlls.ini)

same() { # live repo -> 0 if identical (dirs: ignoring EXCL)
  if [ -d "$1" ]; then diff -rq "${EXCL[@]}" "$1" "$2" >/dev/null 2>&1; else cmp -s "$1" "$2"; fi
}
backup() { mkdir -p "$BK/$(dirname "$1")"; mv "$H/$1" "$BK/$1"; }

mode=${1:-status}; opt=${2:-}
rc=0
for e in "${LINKS[@]}"; do
  t=${e%%|*}; s=$REPO/${e#*|}; live=$H/$t
  if [ ! -e "$s" ]; then echo "no-source  ~/$t  (missing in repo: ${e#*|})"; rc=1; continue; fi
  if [ -L "$live" ]; then
    if [ "$(readlink -f "$live")" = "$(readlink -f "$s")" ]; then [ "$mode" = status ] && echo "ok         ~/$t"; continue; fi
    echo "wrong-link ~/$t -> $(readlink "$live")"
    [ "$mode" = apply ] && { backup "$t"; ln -s "$s" "$live"; echo "  relinked"; }
    continue
  fi
  if [ ! -e "$live" ]; then
    echo "missing    ~/$t"
    [ "$mode" = apply ] && { mkdir -p "$(dirname "$live")"; ln -s "$s" "$live"; echo "  linked"; }
    continue
  fi
  if same "$live" "$s"; then
    echo "not-linked ~/$t (identical)"
    [ "$mode" = apply ] && { backup "$t"; ln -s "$s" "$live"; echo "  linked"; }
  else
    echo "DIFFERS    ~/$t  (diff -r ~/$t $s)"
    if [ "$mode" = apply ] && [ "$opt" = --adopt ]; then
      if [ -d "$live" ]; then rsync -a --exclude '*.bak*' --exclude '*.before*' "$live/" "$s/"; else cp -p "$live" "$s"; fi
      backup "$t"; ln -s "$s" "$live"; echo "  adopted live copy into repo, linked"
    elif [ "$mode" = apply ] && [ "$opt" = --force ]; then
      backup "$t"; ln -s "$s" "$live"; echo "  repo wins, live copy backed up, linked"
    else rc=1; fi
  fi
done
[ -d "$BK" ] && echo "backups: $BK"
exit $rc
