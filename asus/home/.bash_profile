#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc
. "$HOME/.cargo/env"


# Added by Antigravity CLI installer
export PATH="/home/leon/.local/bin:$PATH"

# TypeSafe (fast-jev-compaction) key — sourced from a 600 file, not stored here
[ -r "$HOME/.config/typesafe.env" ] && . "$HOME/.config/typesafe.env"
