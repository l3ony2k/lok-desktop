# nvm / Node for fish
#
# nvm.sh is a bash script, so fish never gets its PATH changes. Work out which
# Node version nvm treats as the default and put its bin directory on PATH;
# that exposes node, npm, and globally installed CLIs such as dsh.
#
# This lives in conf.d because dots-hyprland installs ~/.config/fish with
# `rsync --delete` but excludes conf.d, so it survives updates.

set -gx NVM_DIR $HOME/.nvm
set -l node_root $NVM_DIR/versions/node

if test -d $node_root
    set -l versions (ls -1 $node_root 2>/dev/null | string match -r '^v[0-9].*' | sort -V)
    set -l default_alias (string trim -- (cat $NVM_DIR/alias/default 2>/dev/null))
    set -l chosen

    # ~/.nvm/alias/default can be an exact version ("v20.11.0"), a major
    # version ("20"), or an alias like "lts/*" that we cannot resolve here.
    set -l v (string replace -r '^v' '' -- $default_alias)
    if test -n "$v"; and string match -qr '^[0-9][0-9.]*$' -- $v
        set chosen (string match "v$v" $versions)
        if test -z "$chosen"
            # Major version alias ("20") -> newest matching v20.x
            set chosen (string match "v$v.*" $versions | tail -n 1)
        end
    end

    # Unresolvable alias: fall back to the newest installed version.
    if test -z "$chosen"; and set -q versions[1]
        set chosen $versions[-1]
    end

    if test -n "$chosen"; and not contains -- "$node_root/$chosen/bin" $PATH
        set -gx PATH "$node_root/$chosen/bin" $PATH
    end
end
