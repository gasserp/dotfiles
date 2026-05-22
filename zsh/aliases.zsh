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

# --- Code dir + repo navigation ---
# Override by exporting CODE_DIR before this file is sourced.
export CODE_DIR="${CODE_DIR:-$HOME/code}"

cdc() { cd "$CODE_DIR" || return; }

ccd() {
    if [ ! -d "$CODE_DIR" ]; then
        printf 'Code dir %s not found.\n' "$CODE_DIR" >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        printf 'fzf not installed.\n' >&2
        return 1
    fi
    local sel
    sel="$(find "$CODE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | fzf)" || return
    [ -n "$sel" ] && cd "$sel" || return
}

# --- Terraform shortcuts ---
if command -v terraform >/dev/null 2>&1; then
    tfp() { terraform plan "$@"; }
    tfa() { terraform apply "$@"; }
    tfi() { terraform init "$@"; }
fi

# --- ssh-agent: load all keys with a 3-day lifetime if not already loaded ---
# `ssh-add -t <seconds>` is OpenSSH-native, so this works on macOS and Linux.
ssh_load_keys() {
    [ -d "$HOME/.ssh" ] || return 0
    command -v ssh-add >/dev/null 2>&1 || return 0

    ssh-add -l >/dev/null 2>&1
    local rc=$?
    # 0 = some keys already loaded; 2 = can't connect to agent (skip silently).
    [ "$rc" -eq 0 ] && return 0
    [ "$rc" -eq 2 ] && return 0

    local lifetime=$((3*24*60*60))   # 3 days
    local loaded=0 pub priv
    for pub in "$HOME/.ssh"/*.pub; do
        [ -f "$pub" ] || continue
        priv="${pub%.pub}"
        [ -f "$priv" ] || continue
        if ssh-add -t "$lifetime" "$priv" >/dev/null 2>&1; then
            loaded=$((loaded+1))
        fi
    done
    [ "$loaded" -gt 0 ] && printf 'ssh-agent: loaded %d key(s) with 3-day lifetime\n' "$loaded"
}
ssh_load_keys

# --- gb: fuzzy-pick a local or remote git branch and switch to it ---
# OMZ's git plugin defines `alias gb='git branch'` — drop it so our function wins.
unalias gb 2>/dev/null
gb() {
    if ! command -v git >/dev/null 2>&1; then return 1; fi
    if ! command -v fzf >/dev/null 2>&1; then
        printf 'fzf not installed.\n' >&2
        return 1
    fi
    local sel branch
    sel="$(git for-each-ref --sort=-committerdate \
            --format='%(refname:short)  %(committerdate:relative)  %(authorname)' \
            refs/heads refs/remotes \
        | grep -v '^origin/HEAD' \
        | fzf --ansi --no-multi \
              --preview 'git log --color=always --oneline -20 {1}')" || return
    [ -z "$sel" ] && return
    branch="${sel%% *}"
    if [[ "$branch" == */* ]]; then
        # Remote ref (origin/foo) — create or switch to a local tracking branch.
        git switch --track "$branch" 2>/dev/null || git switch "${branch#*/}"
    else
        git switch "$branch"
    fi
}
