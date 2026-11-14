# ASUS CX54 (SCREEBO) — machine notes

This private repo is end-4/dots-hyprland (`upstream`) plus this machine's
customisations (commits on `main`). `./setup exp-update` pulls from `origin`
(this repo), so the customisations install as part of the update.

- `dots/` — upstream tree with this machine's edits committed on top.
- `asus/home/` + `asus/home-sync.sh` — everything in $HOME the dots do not own (Plasma, three-finger drag,
  fcitx5/rime, ii config.json, ~/.local/bin helpers, herdr/LibreWolf flat themes). After changing such a
  file: add it to MANIFEST in home-sync.sh if new, run `asus/home-sync.sh pull`, commit. `diff` shows drift.
- `asus/system/` — copies of system files changed outside the dotfiles
  (PAM sudo fingerprint line, logind/sleep drop-ins, ASPM tmpfiles, mkinitcpio
  without `kms`, kernel cmdline with memmap, console font, keyd). Not installed
  by setup; restore by hand.
- `asus/src/` — sources: e820-hibfix DKMS module, fingerprint (full rust-fp / crosec-rs
  working-tree snapshot, pam-safe, fprintd shim, PKGBUILDs), power-key debounce, sleep-lock-delay.
- `asus/lok/` — the lok style (see its README); `demo_shoot.sh` + `compose.py` rebuild the README screenshots.
- `asus/RUNBOOK-updates.md` — how to update the system and these dots safely.

Full history and reasoning: ~/.local/share/claude/asus-arch-ops/ on the machine.

## Sync with upstream
    cd ~/dots-hyprland
    git fetch upstream
    git rebase upstream/main        # resolve conflicts in our commits
    git push --force-with-lease origin main
    ./setup exp-update -s --non-interactive keep
