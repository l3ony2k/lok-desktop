# Run quickshell from $HOME. Apps launched from the shell's launcher inherit its
# cwd; if qs was started from a directory that later disappears, every Electron
# app it launches dies with `ENOENT: process.cwd failed ... uv_cwd`.
# Relative `-p PATH` arguments are made absolute first. (asus-arch-ops 2026-11-12)
function qs --wraps qs --description 'quickshell, always run from $HOME'
    set -l args
    set -l prev
    for a in $argv
        if contains -- "$prev" -p --path
            set a (path resolve -- $a)
        end
        set -a args $a
        set prev $a
    end
    env -C $HOME qs $args
end
