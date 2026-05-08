# =============================================================================
# Example PowerShell 7+ profile — replace with your own
# Linked to: $PROFILE.CurrentUserAllHosts
#   Windows: $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#   Linux  : $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1
# =============================================================================

# --- PSReadLine ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -HistoryNoDuplicates
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
