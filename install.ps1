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

# -----------------------------------------------------------------------------
# Without this, a freshly installed shell with the default 'Restricted'
# policy silently skips the profile entirely — no error, no prompt theme,
# no aliases/functions.
# -----------------------------------------------------------------------------
function Set-ProfileExecutionPolicy {
    try {
        $current = Get-ExecutionPolicy -Scope CurrentUser
        if ($current -eq 'Restricted' -or $current -eq 'Undefined') {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            Write-Ok "Set CurrentUser execution policy to RemoteSigned (was $current) so the profile can load."
        }
    } catch {
        Write-Warn2 "Could not update execution policy: $($_.Exception.Message)"
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

    # powershell profile (CurrentUserCurrentHost for the console host)
    # Use the real "Documents" folder, not $HOME\Documents — OneDrive's
    # Known Folder Move can redirect Documents elsewhere (e.g.
    # C:\Users\<you>\OneDrive\Dokumente), which is where $PROFILE points.
    $docsDir = [Environment]::GetFolderPath('MyDocuments')

    # PowerShell 7+ (pwsh) — what "Open a new terminal" should mean.
    $pwshDir = Join-Path $docsDir 'PowerShell'
    New-Link "$Dotfiles\powershell\Microsoft.PowerShell_profile.ps1" `
             "$pwshDir\Microsoft.PowerShell_profile.ps1"

    # Windows PowerShell 5.1 — also link here in case that's still the
    # default profile in Windows Terminal / the one a "new terminal" opens.
    $winPSDir = Join-Path $docsDir 'WindowsPowerShell'
    New-Link "$Dotfiles\powershell\Microsoft.PowerShell_profile.ps1" `
             "$winPSDir\Microsoft.PowerShell_profile.ps1"

    Set-ProfileExecutionPolicy

    # oh-my-posh theme
    $themeDir = Join-Path $HOME '.poshthemes'
    New-Link "$Dotfiles\oh-my-posh\dotfiles.omp.json" "$themeDir\dotfiles.omp.json"

    # lazygit
    $lgDir = Join-Path $env:APPDATA 'lazygit'
    New-Link "$Dotfiles\lazygit\config.yml" "$lgDir\config.yml"

    # az cli
    $azDir = Join-Path $HOME '.azure'
    New-Link "$Dotfiles\azcli\config" "$azDir\config"

    # Windows Terminal — patch settings.json in place rather than overwriting
    # (the file has profiles/schemes/keybinds you don't want to lose).
    Set-WindowsTerminalSettings

    # Claude Code statusline (Git Bash + node are required to run it).
    $claudeDir = Join-Path $HOME '.claude'
    New-Link "$Dotfiles\claude\statusline-command.sh" "$claudeDir\statusline-command.sh"
    New-Link "$Dotfiles\claude\statusline-helper.js"  "$claudeDir\statusline-helper.js"
    Set-ClaudeSettings
}

# -----------------------------------------------------------------------------
# Windows Terminal: merge a small set of preferences into its settings.json
# without replacing it. Idempotent.
# -----------------------------------------------------------------------------
function Set-WindowsTerminalSettings {
    $candidates = @(
        # Store-installed (most common)
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        # Preview Store
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        # Unpackaged
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )

    $settings = $candidates | Where-Object { Test-Path $_ }
    if (-not $settings) {
        Write-Warn2 "Windows Terminal settings.json not found — skipping."
        return
    }

    foreach ($path in $settings) {
        try {
            $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warn2 "Could not parse $path : $($_.Exception.Message)"
            continue
        }

        # Desired top-level settings.
        $desired = @{
            copyOnSelect       = $true
            copyFormatting     = 'none'   # paste-as-plain-text by default
            trimBlockSelection = $true
        }

        $changed = $false
        foreach ($k in $desired.Keys) {
            if ($null -eq $json.$k -or $json.$k -ne $desired[$k]) {
                if ($json.PSObject.Properties.Match($k).Count -gt 0) {
                    $json.$k = $desired[$k]
                } else {
                    $json | Add-Member -NotePropertyName $k -NotePropertyValue $desired[$k] -Force
                }
                $changed = $true
            }
        }

        if (-not $changed) {
            Write-Ok "Windows Terminal settings already match: $path"
            continue
        }

        $backup = "$path.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $path -Destination $backup
        Write-Warn2 "Backed up $path -> $backup"
        $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $path -Encoding UTF8
        Write-Ok "Patched copyOnSelect=true in $path"
    }
}

# -----------------------------------------------------------------------------
# Claude Code: point statusLine at the linked statusline-command.sh without
# clobbering the rest of ~/.claude/settings.json (permissions, etc.).
# -----------------------------------------------------------------------------
function Set-ClaudeSettings {
    $claudeDir = Join-Path $HOME '.claude'
    $path = Join-Path $claudeDir 'settings.json'

    if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

    if (Test-Path $path) {
        try {
            $json = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Warn2 "Could not parse $path : $($_.Exception.Message)"
            return
        }
    } else {
        $json = [PSCustomObject]@{}
    }

    $desired = [PSCustomObject]@{
        type    = 'command'
        command = 'bash ~/.claude/statusline-command.sh'
    }

    if ($json.PSObject.Properties.Match('statusLine').Count -gt 0 -and
        ($json.statusLine.type -eq $desired.type) -and ($json.statusLine.command -eq $desired.command)) {
        Write-Ok "Claude Code statusLine already configured: $path"
        return
    }

    if ($json.PSObject.Properties.Match('statusLine').Count -gt 0) {
        $json.statusLine = $desired
    } else {
        $json | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $desired -Force
    }

    if (Test-Path $path) {
        $backup = "$path.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $path -Destination $backup
        Write-Warn2 "Backed up $path -> $backup"
    }
    $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Ok "Configured Claude Code statusLine in $path"
}

# -----------------------------------------------------------------------------
# Main.
# -----------------------------------------------------------------------------
switch ($Mode) {
    'All'           { Install-Packages; Create-Links }
    'LinkOnly'      { Create-Links }
    'PackagesOnly'  { Install-Packages }
}

Write-Ok "Done. Open a new PowerShell 7 (pwsh) terminal to load the new profile."
Write-Log "Profile is linked for both PowerShell 7 and Windows PowerShell 5.1 — if a 'new terminal' still looks vanilla, check which one Windows Terminal opens by default (Settings > Startup > Default profile)."
Write-Log "If oh-my-posh/fzf/etc. aren't found yet, fully restart your terminal app (or sign out/in) so the PATH changes from winget take effect."
