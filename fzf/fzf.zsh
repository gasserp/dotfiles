# =============================================================================
# fzf shared environment — sourced by both zsh (.zshrc) and bash.
# Linked to: ~/.config/fzf/fzf.zsh
# =============================================================================

# Use fd or ripgrep for the default file walker if available.
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# UI / behavior
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --border=rounded
  --info=inline
  --prompt='» '
  --pointer='▶'
  --marker='✓'
  --bind='ctrl-/:toggle-preview'
  --bind='ctrl-u:preview-page-up'
  --bind='ctrl-d:preview-page-down'
"

# Preview file contents with bat if available, else cat.
if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
else
    export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

# Preview directory contents on Alt-C.
if command -v eza >/dev/null 2>&1; then
    export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always --level=2 {}'"
else
    export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
fi
