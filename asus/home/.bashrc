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
. "$HOME/.cargo/env"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Added by Antigravity CLI installer
export PATH="/home/leon/.local/bin:$PATH"

# >>> magpie agy >>>
function agy {
  if [ -x '/usr/bin/magpie' ]; then '/usr/bin/magpie' agy run "$@"; else command agy "$@"; fi
}
# <<< magpie agy <<<

# TypeSafe (fast-jev-compaction) key — sourced from a 600 file, not stored here
[ -r "$HOME/.config/typesafe.env" ] && . "$HOME/.config/typesafe.env"
