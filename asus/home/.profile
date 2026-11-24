set -a; [ -r "$HOME/.config/environment.d/50-xdg-home.conf" ] && . "$HOME/.config/environment.d/50-xdg-home.conf"; set +a
case ":$PATH:" in *":$CARGO_HOME/bin:"*) ;; *) PATH="$CARGO_HOME/bin:$PATH" ;; esac


# Added by Antigravity CLI installer
export PATH="/home/leon/.local/bin:$PATH"
