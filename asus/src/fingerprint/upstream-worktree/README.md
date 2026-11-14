# Rebuilding the fingerprint stack from upstream

Snapshot of the working trees in ~/Projects/rust-fp-sandbox on 2026-11-14 (they are uncommitted
clones of upstream; this is the only off-machine copy).

| tree | upstream | base commit | changes |
|---|---|---|---|
| rust-fp (daemon, CLI, D-Bus, PAM) | https://github.com/kaukauk/rust-fp | cadbe522a47f232461f3035e765c89ccb191a1d7 | rust-fp.diff (tracked files) + ../pam-safe/ + ../fprintd-shim/ (new crates, add to the workspace members) |
| crosec-rs (FP_INFO v2) | https://github.com/ChocolateLoverRaj/crosec-rs | b67daa7fd2edda15935c5a4d81000bc0767d7572 | crosec-rs.diff |

    git clone https://github.com/kaukauk/rust-fp src && git -C src checkout cadbe522a47f
    git -C src apply ../upstream-worktree/rust-fp.diff
    cp -r ../pam-safe ../fprintd-shim src/
    git clone https://github.com/ChocolateLoverRaj/crosec-rs && git -C crosec-rs checkout b67daa7fd2ed
    git -C crosec-rs apply ../upstream-worktree/crosec-rs.diff

Packages: ../PKGBUILD -> rust-fp-cros-local (1.0.0-6), ../fprintd-shim/pkg/PKGBUILD -> rust-fp-fprintd-local (0.1.0-1).
The older patches/ (daemon-changes.diff etc.) are the step-by-step history; upstream-worktree/ is the current state.
