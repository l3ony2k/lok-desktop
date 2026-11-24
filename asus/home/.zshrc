# ~/.zshrc — ASUS (Arch + Hyprland). Symlinked from ~/.dotfiles/asus/home/.zshrc.
# Forked on 2026-11-24 from the MacBook/VPS dotfiles repo; the two now evolve separately.
# Machine-local extras that should stay out of git go in ~/.zshrc.local.

# ---- Startup banner ---------------------------------------------------------
# Must run before the p10k instant prompt, otherwise p10k warns about console output.
# The layout is ~107 columns wide (logo + info); below that it wraps, so skip it
# in narrow terminals/panes. Bump FASTFETCH_MIN_COLS if the info lines get longer.
FASTFETCH_MIN_COLS=${FASTFETCH_MIN_COLS:-110}
if [[ -o interactive && $TERM != dumb ]] && (( $+commands[fastfetch] )) \
   && (( ${COLUMNS:-$(tput cols 2>/dev/null || print 0)} >= FASTFETCH_MIN_COLS )); then
  fastfetch
fi

# ---- Powerlevel10k instant prompt (keep near the top) -----------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ---- oh-my-zsh ----------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
export ZSH_COMPDUMP="$ZSH/cache/.zcompdump-$HOST"   # must be set before oh-my-zsh.sh
typeset -U path fpath   # keep PATH entries unique (enforced again at the end)

# Completions must be on fpath before oh-my-zsh runs compinit.
# >>> grok installer >>>
if [[ -d "$HOME/.grok" ]]; then
  export PATH="$HOME/.grok/bin:$PATH"
  fpath=(~/.grok/completions/zsh $fpath)
fi
# <<< grok installer <<<

# Order matters: zsh-syntax-highlighting after the other plugins,
# history-substring-search after zsh-syntax-highlighting.
plugins=(
  git
  docker
  docker-compose
  dirhistory
  you-should-use
  autojump
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
)

source "$ZSH/oh-my-zsh.sh"

# Up/Down search history for what you've typed so far (both key encodings).
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ---- Environment --------------------------------------------------------------
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"   # install.sh generates this locale on Linux

# ---- Prompt -------------------------------------------------------------------
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---- Aliases ------------------------------------------------------------------
# Ubuntu ships bat as "batcat"; macOS/Homebrew calls it "bat".
(( $+commands[batcat] && ! $+commands[bat] )) && alias bat='batcat'
if (( $+commands[eza] )); then
  alias ls='eza'
  alias ll='eza -alhg --modified --time-style=long-iso --grid'
fi
alias rm='rm -iv'
alias mv='mv -iv'
alias cp='cp -iv'

# ---- Language tooling (each block is skipped if not installed) ----------------
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - zsh)"
  [[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]] && eval "$(pyenv virtualenv-init -)"
fi

# ---- PATH ---------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
# opencode
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

# ---- nnn --------------------------------------------------------------------
# Helpers (tmux.conf, edit) live in .config/nnn/; plugins come from nnn's getplugs.
if (( $+commands[nnn] )); then
  export NNN_OPTS="adeH"                                     # a: auto preview FIFO, e: open text in $EDITOR, d: detail view, H: show hidden
  export NNN_PLUG='p:preview-tui;f:fzcd;o:fzopen'            # ;p preview, ;f fuzzy cd, ;o fuzzy open
  export NNN_BMS="h:$HOME;c:$HOME/.config;d:$HOME/.dotfiles" # b then key to jump
  export NNN_TRASH=1                                          # delete moves to trash (trash-cli)
  export EDITOR=${EDITOR:-vim}

  # n: cd on quit (upstream quitcd), preview open by default.
  # Outside tmux, runs inside a private tmux (socket "nnn", no status bar) so preview-tui can split.
  n () {
      [ "${NNNLVL:-0}" -eq 0 ] || { echo "nnn is already running"; return; }
      export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
      if [ -n "$TMUX" ]; then
          VISUAL="$HOME/.config/nnn/edit" command nnn -P p "$@"
      else
          tmux -L nnn -f "${XDG_CONFIG_HOME:-$HOME/.config}/nnn/tmux.conf" \
              new-session -c "$PWD" -e "NNN_TMPFILE=$NNN_TMPFILE" \
              -e "VISUAL=$HOME/.config/nnn/edit" -- nnn -P p "$@"
      fi
      [ ! -f "$NNN_TMPFILE" ] || { . "$NNN_TMPFILE"; rm -f -- "$NNN_TMPFILE" > /dev/null; }
  }
fi

# ---- yazi -------------------------------------------------------------------
if (( $+commands[yazi] )); then
  # y: cd on quit (upstream wrapper).
  y () {
      local tmp cwd
      tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return 1
      command yazi "$@" --cwd-file="$tmp"
      if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
      fi
      rm -f -- "$tmp"
  }
fi

# ---- Machine-specific settings (not in git) -----------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# `export PATH=...` lines bypass typeset -U; re-assigning the array drops the duplicates.
path=($path)
