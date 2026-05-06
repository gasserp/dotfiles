#!/usr/bin/env bash
# =============================================================================
# Linux installer for the dotfiles repo.
# Installs the listed tools and symlinks the example configs into place.
#
# Usage:
#   ./install.sh                 # install everything
#   ./install.sh link-only       # only create symlinks (skip package install)
#   ./install.sh packages-only   # only install packages (skip linking)
# =============================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-all}"

log()   { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

# -----------------------------------------------------------------------------
# Detect the package manager.
# -----------------------------------------------------------------------------
detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf  >/dev/null 2>&1; then echo dnf
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    else echo unknown
    fi
}

PM="$(detect_pm)"
SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

# -----------------------------------------------------------------------------
# Package installation.
# -----------------------------------------------------------------------------
install_packages() {
    log "Detected package manager: $PM"
    case "$PM" in
        apt)
            $SUDO apt-get update -y
            $SUDO apt-get install -y \
                vim git curl wget unzip ca-certificates gnupg \
                zsh fzf fd-find ripgrep bat \
                lazygit 2>/dev/null || \
            $SUDO apt-get install -y \
                vim git curl wget unzip ca-certificates gnupg \
                zsh fzf fd-find ripgrep bat
            # bat ships as `batcat` on Debian/Ubuntu — symlink to bat.
            if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
                mkdir -p "$HOME/.local/bin"
                ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
            fi
            # fd ships as `fdfind`.
            if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
                mkdir -p "$HOME/.local/bin"
                ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
            fi
            ;;
        dnf)
            $SUDO dnf install -y vim git curl wget unzip zsh fzf fd-find ripgrep bat lazygit
            ;;
        pacman)
            $SUDO pacman -Sy --noconfirm vim git curl wget unzip zsh fzf fd ripgrep bat lazygit
            ;;
        *)
            warn "Unknown package manager — install tools manually."
            ;;
    esac

    install_vscode
    install_azure_cli
    install_oh_my_posh
    install_pwsh
    install_zsh_plugins
}

install_vscode() {
    if command -v code >/dev/null 2>&1; then
        ok "VS Code already installed."
    else
        log "Installing VS Code…"
        case "$PM" in
            apt)
                $SUDO install -d -m 0755 /etc/apt/keyrings
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                    | gpg --dearmor | $SUDO tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
                echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
                    | $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null
                $SUDO apt-get update -y && $SUDO apt-get install -y code
                ;;
            dnf)
                $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
                printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
                    | $SUDO tee /etc/yum.repos.d/vscode.repo >/dev/null
                $SUDO dnf install -y code
                ;;
            *)
                warn "Skipping VS Code (install manually for $PM)."
                ;;
        esac
    fi

    if command -v code >/dev/null 2>&1 && [ -f "$DOTFILES/vscode/extensions.txt" ]; then
        log "Installing VS Code extensions…"
        grep -v '^\s*#' "$DOTFILES/vscode/extensions.txt" | grep -v '^\s*$' | while read -r ext; do
            code --install-extension "$ext" --force >/dev/null 2>&1 || warn "  failed: $ext"
        done
    fi
}

install_azure_cli() {
    if command -v az >/dev/null 2>&1; then
        ok "Azure CLI already installed."
        return
    fi
    log "Installing Azure CLI…"
    case "$PM" in
        apt)    curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash ;;
        dnf)    $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
                $SUDO dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm 2>/dev/null || true
                $SUDO dnf install -y azure-cli ;;
        pacman) $SUDO pacman -Sy --noconfirm azure-cli ;;
        *)      warn "Install azure-cli manually." ;;
    esac
}

install_pwsh() {
    if command -v pwsh >/dev/null 2>&1; then
        ok "PowerShell already installed."
        return
    fi
    log "Installing PowerShell 7…"
    case "$PM" in
        apt)
            source /etc/os-release
            wget -q "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/psmsprod.deb
            $SUDO dpkg -i /tmp/psmsprod.deb && rm /tmp/psmsprod.deb
            $SUDO apt-get update -y && $SUDO apt-get install -y powershell
            ;;
        dnf)
            $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
            curl -sSL https://packages.microsoft.com/config/rhel/9/prod.repo | $SUDO tee /etc/yum.repos.d/microsoft.repo >/dev/null
            $SUDO dnf install -y powershell
            ;;
        pacman)
            warn "Install powershell-bin from AUR for PowerShell on Arch."
            ;;
    esac

    if command -v pwsh >/dev/null 2>&1; then
        log "Installing PSReadLine + PSFzf modules…"
        pwsh -NoProfile -Command "Install-Module -Name PSReadLine,PSFzf -Force -Scope CurrentUser -AllowClobber" || true
    fi
}

install_oh_my_posh() {
    if command -v oh-my-posh >/dev/null 2>&1; then
        ok "oh-my-posh already installed."
        return
    fi
    log "Installing oh-my-posh…"
    mkdir -p "$HOME/.local/bin"
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
}

install_zsh_plugins() {
    local plug_dir="$HOME/.local/share/zsh/plugins"
    mkdir -p "$plug_dir"
    log "Installing zsh plugins (no oh-my-zsh) into $plug_dir"
    _clone_or_pull() {
        local repo="$1" dst="$2"
        if [ -d "$dst/.git" ]; then
            git -C "$dst" pull --ff-only --quiet || true
        else
            git clone --depth=1 "$repo" "$dst" --quiet
        fi
    }
    _clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$plug_dir/zsh-autosuggestions"
    _clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting "$plug_dir/zsh-syntax-highlighting"
    _clone_or_pull https://github.com/zsh-users/zsh-completions          "$plug_dir/zsh-completions"
}

# -----------------------------------------------------------------------------
# Symlinks. `link <src> <dst>` creates dst -> src, backing up any real file.
# -----------------------------------------------------------------------------
link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing $dst -> $backup"
        mv "$dst" "$backup"
    fi
    ln -s "$src" "$dst"
    ok "linked: $dst -> $src"
}

create_links() {
    log "Linking configs…"

    # vim
    link "$DOTFILES/vim/vimrc" "$HOME/.vimrc"

    # zsh (Linux only)
    link "$DOTFILES/zsh/zshrc"        "$HOME/.zshrc"
    link "$DOTFILES/zsh/aliases.zsh"  "$HOME/.config/zsh/aliases.zsh"

    # fzf
    link "$DOTFILES/fzf/fzf.zsh" "$HOME/.config/fzf/fzf.zsh"

    # oh-my-posh
    link "$DOTFILES/oh-my-posh/dotfiles.omp.json" "$HOME/.config/oh-my-posh/dotfiles.omp.json"

    # lazygit
    link "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"

    # az cli
    link "$DOTFILES/azcli/config" "$HOME/.azure/config"

    # vscode
    link "$DOTFILES/vscode/settings.json"     "$HOME/.config/Code/User/settings.json"
    link "$DOTFILES/vscode/keybindings.json"  "$HOME/.config/Code/User/keybindings.json"

    # powershell (Linux profile location)
    link "$DOTFILES/powershell/Microsoft.PowerShell_profile.ps1" \
         "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
}

# -----------------------------------------------------------------------------
# Main.
# -----------------------------------------------------------------------------
case "$MODE" in
    all)            install_packages; create_links ;;
    link-only)      create_links ;;
    packages-only)  install_packages ;;
    *)              error "Unknown mode: $MODE"; exit 2 ;;
esac

ok "Done. Open a new shell to load the new config."
