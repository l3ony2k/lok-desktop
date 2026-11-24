# rustup/cargo live under XDG (asus 2026-11-24; same values as ~/.config/environment.d/50-xdg-home.conf)
set -gx CARGO_HOME $HOME/.local/share/cargo
set -gx RUSTUP_HOME $HOME/.local/share/rustup
fish_add_path -g $CARGO_HOME/bin
