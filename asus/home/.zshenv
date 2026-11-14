# Quickshell/end-4 generated terminal colours.
# This must run before ~/.zshrc: the p10k instant prompt captures (and reports)
# any console output produced while ~/.zshrc is being sourced, so the palette
# has to be applied in an earlier startup file or every new shell shows the
# "Console output during zsh initialization detected" warning.
if [[ -o interactive && -t 1 && -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt ]]; then
  cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
  # 2026-11-12: the generated file ends with an unterminated OSC 708 (ESC without the
  # trailing backslash), so kitty swallowed everything up to the next ST: the top of
  # the fastfetch banner vanished. Close it here instead of touching the ii generator.
  printf '\e\\'
fi
