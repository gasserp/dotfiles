# Example shared aliases — replace with your own
# Linked to: ~/.config/zsh/aliases.zsh

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- ls ---
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first'
    alias ll='eza -lah --group-directories-first --git'
    alias tree='eza --tree'
else
    alias ll='ls -lah --color=auto'
fi

# --- cat ---
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'

# --- grep ---
alias grep='grep --color=auto'

# --- git ---
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
alias gp='git pull'
alias lg='lazygit'

# --- editors ---
alias v='vim'

# --- safety ---
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
