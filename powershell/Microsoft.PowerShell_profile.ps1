# =============================================================================
# Example PowerShell profile — replace with your own
# Linked to: $PROFILE.CurrentUserCurrentHost (console host)
#   Windows: $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1        (PowerShell 7+)
#            $HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 (Windows PowerShell 5.1)
#   Linux  : $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1
# =============================================================================

# --- PSReadLine ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    $psrl = Get-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    # Prediction features need PSReadLine 2.1+ (Windows PowerShell 5.1 ships 2.0.0).
    if ($psrl.Version -ge [version]'2.1.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }
    if ($psrl.Version -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# --- PSFzf (fzf integration for PowerShell) ---
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PsFzfOption -EnableAliasFuzzyEdit -EnableAliasFuzzyHistory -EnableAliasFuzzyKillProcess
}

# --- oh-my-posh ---
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $themePath = Join-Path $HOME '.poshthemes/dotfiles.omp.json'
    if (Test-Path $themePath) {
        oh-my-posh init pwsh --config $themePath | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# --- Aliases ---
Set-Alias -Name g    -Value git
Set-Alias -Name vi   -Value vim
Set-Alias -Name which -Value Get-Command

if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit -Option AllScope -Force
}

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function ll { Get-ChildItem -Force @args }

# --- Code dir + repo navigation ---
# Override by setting $env:CODE_DIR before the profile loads.
$CodeDir = if ($env:CODE_DIR) { $env:CODE_DIR } else { Join-Path $HOME 'code' }

function cdc { Set-Location -LiteralPath $CodeDir }

function ccd {
    if (-not (Test-Path -LiteralPath $CodeDir)) {
        Write-Warning "Code dir '$CodeDir' not found."
        return
    }
    $dirs = Get-ChildItem -LiteralPath $CodeDir -Directory -ErrorAction SilentlyContinue
    if (-not $dirs) { Write-Warning "No repos in '$CodeDir'."; return }
    $selection = $dirs | Select-Object -ExpandProperty FullName | fzf
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($selection)) { return }
    Set-Location -LiteralPath $selection
}

# --- Terraform shortcuts ---
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    function tfp { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args) terraform plan @Args }
    function tfa { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args) terraform apply @Args }
    function tfi { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args) terraform init @Args }
}

# --- ssh-agent: load all keys with a 3-day lifetime if not already loaded ---
# `ssh-add -t <seconds>` is OpenSSH-native, supported by Windows OpenSSH too.
function Add-SshKeysIfMissing {
    if (-not (Get-Command ssh-add -ErrorAction SilentlyContinue)) { return }
    $sshDir = Join-Path $HOME '.ssh'
    if (-not (Test-Path $sshDir)) { return }

    # On Windows, make sure the OpenSSH Authentication Agent service is running.
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $svc = Get-Service ssh-agent -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            try { Start-Service ssh-agent -ErrorAction Stop } catch {
                Write-Verbose "Could not start ssh-agent service: $($_.Exception.Message)"
            }
        }
    }

    & ssh-add -l 2>&1 | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -eq 0 -or $rc -eq 2) { return }   # already loaded, or no agent

    $lifetime = 3 * 24 * 60 * 60
    $loaded = 0
    Get-ChildItem -Path $sshDir -File -Filter '*.pub' -ErrorAction SilentlyContinue | ForEach-Object {
        $priv = $_.FullName -replace '\.pub$',''
        if (Test-Path -LiteralPath $priv) {
            & ssh-add -t $lifetime $priv 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $loaded++ }
        }
    }
    if ($loaded -gt 0) {
        Write-Host "ssh-agent: loaded $loaded key(s) with 3-day lifetime"
    }
}
Add-SshKeysIfMissing

# --- gb: fuzzy-pick a local or remote git branch and switch to it ---
function gb {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Warning "fzf not installed."
        return
    }

    $branches = git for-each-ref --sort=-committerdate `
        --format='%(refname:short)  %(committerdate:relative)  %(authorname)' `
        refs/heads refs/remotes |
        Where-Object { $_ -notmatch '^origin/HEAD' }
    if (-not $branches) { return }

    $selection = $branches | fzf --ansi --no-multi `
        --preview 'git log --color=always --oneline -20 {1}'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($selection)) { return }

    $branch = ($selection -split '\s+', 2)[0]
    if ($branch -match '/' -and $branch -ne 'HEAD') {
        git switch --track $branch 2>$null
        if ($LASTEXITCODE -ne 0) { git switch ($branch -replace '^[^/]+/', '') }
    } else {
        git switch $branch
    }
}

# --- Az CLI tab completion ---
if (Get-Command az -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $completion_file = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'
        az 2>&1 | Out-Null
        Get-Content $completion_file | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
        }
        Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES,
            Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE,
            Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL -ErrorAction SilentlyContinue
    }
}
