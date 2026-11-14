fish_add_path ~/.local/bin

# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end


# Added by Antigravity CLI installer
set -gx PATH "/home/leon/.local/bin" $PATH

# >>> magpie agy >>>
function agy
    if test -x '/usr/bin/magpie'
        '/usr/bin/magpie' agy run $argv
    else
        command agy $argv
    end
end
# <<< magpie agy <<<

# TypeSafe (fast-jev-compaction) key — sourced from a 600 file, not stored here
test -r ~/.config/typesafe.env; and source ~/.config/typesafe.env
