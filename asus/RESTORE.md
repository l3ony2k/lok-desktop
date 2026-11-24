# Rebuild this setup on a fresh Arch install

Goal: a new Arch install ends up with the same desktop (Hyprland + ii in the lok theme), shell,
input method, fonts, helper scripts and system tweaks as this ASUS. Apps' own data (browser
profiles, chat logins, notes) is not covered; neither are secrets (step 6).

The steps are in `asus/install.sh`; run them one at a time the first time, so you can read the
output: `asus/install.sh list` shows them, `asus/install.sh <stage>` runs one. Each is safe to
re-run.

## 0. Before you start

- Arch installed with a user `leon` (the scripts use `$HOME`, but a few system files and the
  LibreWolf profile path mention `leon` / `wobsi8ej`), network, `sudo`, `git`, `base-devel`.
- This laptop used: systemd-boot with UKIs, btrfs (`@`, `@home`, `@log`, `@pkg`), a 32 GiB
  `/swapfile` in `@` for hibernate, zram. Disk layout and bootloader are **not** recreated by
  anything here; `asus/system/etc/fstab`, `etc/kernel/cmdline`, `etc/mkinitcpio*` and
  `boot/loader/loader.conf` are the reference.
- Log in to GitHub (`gh auth login`), then:

      git clone --recurse-submodules https://github.com/l3ony2k/dots-hyprland-asus.git ~/.dotfiles
      cd ~/.dotfiles
      git remote add upstream https://github.com/end-4/dots-hyprland.git

## 1. `packages` — repo and AUR packages
Installs `asus/packages/pacman.txt` with pacman and `asus/packages/aur.txt` with yay (bootstraps
`yay-bin` if missing). The lists are refreshed by `asus/home-sync.sh pull`, so they match the
machine as of the last commit. Review `pacman.txt` first on different hardware: it contains
laptop-specific packages (sof-firmware, keyd, ...).

## 2. `end4` — illogical-impulse
Runs end-4's `./setup install`: its dependency meta-packages (`illogical-impulse-*`, quickshell),
permissions/services, and a first copy of every dots file. On a machine where the configs are
already symlinked it runs `./setup install --skip-allfiles` instead. Answer its prompts; skip
the parts you don't want (fish, plasma integration).

## 3. `home` — program-written configs
`asus/home-sync.sh restore` copies the `MANIFEST` files (KDE, ii `config.json`, fcitx5 profile,
herdr settings, GTK, lok fonts, user units, the patched 3-finger-drag PKGBUILD) into `$HOME`.
It backs up whatever it overwrites to `~/.local/state/home-sync/`.

## 4. `links` — hand-edited configs
`asus/links.sh apply` replaces the copies end-4 just made (and any shell files) with symlinks
into this repo: `~/.config/quickshell/ii`, `~/.config/hypr`, kitty/foot/fuzzel/fontconfig/matugen,
`~/.zshrc` & co., `~/.gitconfig`, `~/.local/bin` helpers, rime patches, herdr mods, LibreWolf CSS.
Anything identical is replaced silently (backup in `~/.local/state/dotfiles-links/`); anything
that differs is listed as DIFFERS and left alone — inspect it, then `apply --force` (repo wins)
or `apply --adopt` (keep the live one, then `git diff`).

LibreWolf: the CSS links assume the profile dir `wobsi8ej.default-release`. A new install gets a
new profile name: edit the two LibreWolf lines in `links.sh` (or rename the profile) and set
`toolkit.legacyUserProfileCustomizations.stylesheets = true` in `about:config`.

## 5. `fonts`, `services`
- `fonts` downloads Ioskeley Mono Term Nerd Font (kitty) from its GitHub release; Paper Mono
  Nerd Font and the lok icon font come with step 3. Then `fc-cache`.
- `services` enables the user units (sleep-lock-delay, vibe-usage) and the system units this
  machine runs (greetd, keyd, mihomo, tailscaled, ufw, power-profiles-daemon, ...), skipping
  any whose package isn't installed.

## 6. Secrets and logins (by hand)
| What | Where it goes |
|---|---|
| SSH keys | `~/.ssh/` (copy from a backup; `chmod 600`) |
| Mihomo subscription URL | `~/.config/mihomo/sub-url` (`chmod 600`), then `mihomo-update-sub` writes `/etc/mihomo/config.yaml` |
| TypeSafe key | `~/.config/typesafe.env` |
| Tailscale | `sudo tailscale up` |
| GitHub CLI | `gh auth login` (git uses it as credential helper, see `.gitconfig`) |
| Fingerprints | enroll again (`fprintd-enroll`) after step 8 |

## 7. `system` — files under /etc, /usr/local, /boot
`asus/install.sh system` (= `asus/system-diff.sh`) lists each tracked system file as same /
DIFFERS / missing. Nothing is written; copy by hand with `sudo install -m644 asus/system/<path> /<path>`.

- Safe to copy as-is: `etc/keyd/cros.conf` (Chromebook keys), `etc/systemd/logind.conf.d/*`,
  `etc/systemd/sleep.conf.d/*`, `etc/tmpfiles.d/*`, `etc/sysctl.d/*`, `etc/vconsole.conf`,
  `etc/fonts/local.conf`, `etc/greetd/` (see `etc/greetd/README-sessions.md`; recreate the two
  session symlinks), `etc/ufw/user*.rules`, `etc/conf.d/wireless-regdom`, `usr/local/bin/*`
  (fan-mode, camera-ctl, ssh-lan-toggle, ...) with `etc/sudoers.d/*` (check with `visudo -c`),
  `usr/lib/systemd/system-sleep/fan-mode`, `etc/systemd/system/fan-mode-reset.service`.
- Machine-specific — merge, never overwrite: `etc/fstab` (UUIDs), `etc/kernel/cmdline`
  (root UUID, `resume_offset` of the swapfile, `memmap`), `etc/mkinitcpio.conf` and
  `etc/mkinitcpio.d/*.preset` (then `sudo mkinitcpio -P`), `boot/loader/loader.conf`.
- PAM (`etc/pam.d/sudo`, `polkit-1`, `greetd`, `kde-fingerprint`) only after the fingerprint
  stack from step 8 works; a broken PAM line locks you out of sudo. Keep a root shell open.

## 8. Local builds (this laptop's hardware)
Sources in `asus/src/`, history in the ops log (`~/.local/share/claude/asus-arch-ops/`):
- `e820-hibfix-1.2/` — DKMS module that makes hibernate resume work on this board
  (`sudo cp -r asus/src/e820-hibfix-1.2 /usr/src/ && sudo dkms install e820-hibfix/1.2`),
  plus the cmdline/mkinitcpio parts of step 7.
- `fingerprint/` — rust-fp for the ChromeOS fingerprint sensor: `PKGBUILD` (rust-fp-cros-local,
  `makepkg -si`), PAM helper `pam-safe`, fprintd shim, patches. rust-fp-fprintd-local was built
  the same way; see the fingerprint entries in the ops log before rebuilding.
- `battery-limit/` — EC charge limit script, service and sudoers rule.
- `~/.local/src/aur-local/linux-3-finger-drag-git` (restored in step 3) — patched AUR package
  for Plasma's three-finger drag: `makepkg -si` there.
- `fw-ectool-git` comes from the AUR (step 1).

## 9. Check
- Log in to Hyprland from greetd; the bar should be lok (square, monochrome).
- `asus/links.sh status` → all `ok`; `asus/home-sync.sh diff` → nothing; `git status` clean.
- `~/.local/bin/ii-restart --check` prints nothing.
- Then read `RUNBOOK-updates.md` for keeping it updated.
