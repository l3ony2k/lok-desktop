#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
set -a; [ -r "$HOME/.config/environment.d/50-xdg-home.conf" ] && . "$HOME/.config/environment.d/50-xdg-home.conf"; set +a
case ":$PATH:" in *":$CARGO_HOME/bin:"*) ;; *) PATH="$CARGO_HOME/bin:$PATH" ;; esac
HISTFILE="$HOME/.local/state/bash/history"

export NVM_DIR="${NVM_DIR:-$HOME/.local/share/nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Added by Antigravity CLI installer
export PATH="/home/leon/.local/bin:$PATH"

# TypeSafe (fast-jev-compaction) key — sourced from a 600 file, not stored here
[ -r "$HOME/.config/typesafe.env" ] && . "$HOME/.config/typesafe.env"
