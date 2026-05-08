# =============================================================================
# Windows installer for the dotfiles repo.
# Installs the listed tools via winget and links the example configs into place.
#
# Usage (from an elevated PowerShell 7+ window — winget can require admin):
#   .\install.ps1                  # install everything
#   .\install.ps1 -Mode LinkOnly   # only create links
#   .\install.ps1 -Mode PackagesOnly
# =============================================================================
[CmdletBinding()]
param(
    [ValidateSet('All', 'LinkOnly', 'PackagesOnly')]
    [string]$Mode = 'All'
)

$ErrorActionPreference = 'Stop'
$Dotfiles = $PSScriptRoot

function Write-Log  { param($m) Write-Host "[*] $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "[+] $m" -ForegroundColor Green }
function Write-Warn2 { param($m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "[x] $m" -ForegroundColor Red }

# -----------------------------------------------------------------------------
# winget package installation. Each entry: id, optional source override.
# -----------------------------------------------------------------------------
function Install-Packages {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
        return
    }

    $packages = @(
        @{ Id = 'Microsoft.PowerShell';   Name = 'PowerShell 7' },
        @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' },
        @{ Id = 'vim.vim';                Name = 'Vim' },
        @{ Id = 'Microsoft.AzureCLI';     Name = 'Azure CLI' },
        @{ Id = 'junegunn.fzf';           Name = 'fzf' },
        @{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'oh-my-posh' },
        @{ Id = 'jesseduffield.lazygit';  Name = 'lazygit' },
        @{ Id = 'Git.Git';                Name = 'Git' },
        @{ Id = 'sharkdp.fd';             Name = 'fd' },
        @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep' },
        @{ Id = 'sharkdp.bat';            Name = 'bat' }
    )

    foreach ($p in $packages) {
        Write-Log "Installing $($p.Name) ($($p.Id))…"
        winget install --id $p.Id --accept-source-agreements --accept-package-agreements --silent --exact 2>$null
        if ($LASTEXITCODE -eq 0)   { Write-Ok "$($p.Name) installed." }
        elseif ($LASTEXITCODE -eq -1978335189) { Write-Ok "$($p.Name) already installed." }
        else { Write-Warn2 "$($p.Name) install returned $LASTEXITCODE." }
    }

    Install-VSCodeExtensions
    Install-PSModules
}

function Install-VSCodeExtensions {
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) { Write-Warn2 "VS Code 'code' CLI not on PATH yet — open a new shell and run install.ps1 -Mode PackagesOnly to add extensions."; return }
    $extFile = Join-Path $Dotfiles 'vscode/extensions.txt'
    if (-not (Test-Path $extFile)) { return }
    Write-Log "Installing VS Code extensions…"
    Get-Content $extFile | Where-Object { $_ -and $_ -notmatch '^\s*#' } | ForEach-Object {
        & code --install-extension $_ --force | Out-Null
    }
}

function Install-PSModules {
    Write-Log "Installing PowerShell modules (PSReadLine, PSFzf)…"
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    foreach ($mod in 'PSReadLine','PSFzf') {
        try {
            Install-Module -Name $mod -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -ErrorAction Stop
            Write-Ok "$mod installed."
        } catch {
            Write-Warn2 "Failed to install $mod : $($_.Exception.Message)"
        }
    }
}

# -----------------------------------------------------------------------------
# Symlink helper. Falls back to copy if symlinks aren't permitted.
# -----------------------------------------------------------------------------
function New-Link {
    param([string]$Source, [string]$Destination)
    $dir = Split-Path -Parent $Destination
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (Test-Path $Destination) {
        $item = Get-Item $Destination -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            Remove-Item $Destination -Force
        } else {
            $backup = "$Destination.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-Warn2 "Backing up existing $Destination -> $backup"
            Move-Item $Destination $backup
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -ErrorAction Stop | Out-Null
        Write-Ok "linked: $Destination -> $Source"
    } catch {
        Write-Warn2 "Symlink failed (need admin or Developer Mode). Copying instead: $Destination"
        Copy-Item $Source $Destination -Force
    }
}

function Create-Links {
    Write-Log "Linking configs…"

    # vim
    New-Link "$Dotfiles\vim\vimrc" "$HOME\_vimrc"

    # vscode
    $vscodeUser = Join-Path $env:APPDATA 'Code\User'
    New-Link "$Dotfiles\vscode\settings.json"    "$vscodeUser\settings.json"
    New-Link "$Dotfiles\vscode\keybindings.json" "$vscodeUser\keybindings.json"

    # powershell profile (CurrentUserAllHosts)
    $pwshDir = Join-Path $HOME 'Documents\PowerShell'
    New-Link "$Dotfiles\powershell\Microsoft.PowerShell_profile.ps1" `
             "$pwshDir\Microsoft.PowerShell_profile.ps1"

    # oh-my-posh theme
    $themeDir = Join-Path $HOME '.poshthemes'
    New-Link "$Dotfiles\oh-my-posh\dotfiles.omp.json" "$themeDir\dotfiles.omp.json"

    # lazygit
    $lgDir = Join-Path $env:APPDATA 'lazygit'
    New-Link "$Dotfiles\lazygit\config.yml" "$lgDir\config.yml"

    # az cli
    $azDir = Join-Path $HOME '.azure'
    New-Link "$Dotfiles\azcli\config" "$azDir\config"
}

# -----------------------------------------------------------------------------
# Main.
# -----------------------------------------------------------------------------
switch ($Mode) {
    'All'           { Install-Packages; Create-Links }
    'LinkOnly'      { Create-Links }
    'PackagesOnly'  { Install-Packages }
}

Write-Ok "Done. Open a new PowerShell session to load the new profile."
