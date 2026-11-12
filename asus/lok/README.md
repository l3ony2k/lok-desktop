# lok style for ii (ASUS)

Greyscale, square, thin-line style layered on end-4 ii. Switch: `appearance.style` = `lok` | `material`
(ii Settings > Style, or config.json). Palette `lok` is fixed (does not follow the wallpaper).

- ii code: `Appearance.lok` gates every change; `material` keeps upstream behaviour.
- Colours: `scripts/colors/lok/lok_palette.py` + `apply-lok.sh` (called by `switchwall.sh`), also writes
  `~/.config/hypr/custom/lok.lua` (generated; rounding 0, 1 px grey border, no shadow), loaded by `custom/general.lua`.
- Icons: `fonts/LokIcons*.ttf` -> `~/.local/share/fonts/lok-icons/` (Tabler Icons 300/200, MIT) with
  Material Symbols name ligatures. Rebuild: `icon-build/build_lok_icons.py <tabler ttf> "Lok Icons" LokIcons.ttf`.
- Wallpapers: `wallpapers/lok-dots-{dark,light}.png` -> `~/Pictures/wallpapers/`.
- Back to the previous look: tag `pre-lok-style-2026-11-12` + `asus/snapshots/2026-11-12-pre-lok/restore.sh`,
  or just set style to `material`.
