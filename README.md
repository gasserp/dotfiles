# dotfiles

Cross-platform configuration for the tools I use, with one bootstrap script per
OS that installs everything and symlinks the configs into place.

> All configs in this repo are **example starters** — replace them with your
> real configs over time.

## What's in here

| Tool          | Path in repo                                        | Linux                                  | Windows                                  |
|---------------|-----------------------------------------------------|----------------------------------------|------------------------------------------|
| Vim           | `vim/vimrc`                                         | `~/.vimrc`                             | `%USERPROFILE%\_vimrc`                   |
| VS Code       | `vscode/settings.json`, `keybindings.json`          | `~/.config/Code/User/`                 | `%APPDATA%\Code\User\`                   |
| VS Code ext.  | `vscode/extensions.txt`                             | installed via `code --install-extension`                                          |
| PowerShell    | `powershell/Microsoft.PowerShell_profile.ps1`       | `~/.config/powershell/`                | `~\Documents\PowerShell\` (7+) and `~\Documents\WindowsPowerShell\` (5.1) |
| Azure CLI     | `azcli/config`                                      | `~/.azure/config`                      | `%USERPROFILE%\.azure\config`            |
| Zsh (Linux)   | `zsh/zshrc`, `zsh/aliases.zsh`                      | `~/.zshrc`, `~/.config/zsh/aliases.zsh`| —                                        |
| fzf           | `fzf/fzf.zsh`                                       | `~/.config/fzf/fzf.zsh`                | (PSFzf module in the PowerShell profile) |
| oh-my-posh    | `oh-my-posh/dotfiles.omp.json`                      | `~/.config/oh-my-posh/`                | `~\.poshthemes\`                         |
| lazygit       | `lazygit/config.yml`                                | `~/.config/lazygit/config.yml`         | `%APPDATA%\lazygit\config.yml`           |
| Ghostty       | `ghostty/config` (theme: `OneHalfDark`)             | `~/.config/ghostty/config` (+ macOS Application Support) | — (not supported on Windows) |
| Claude Code   | `claude/statusline-command.sh`, `statusline-helper.js` | `~/.claude/` (+ `statusLine` set in `~/.claude/settings.json`) | `~\.claude\` (same, via Git Bash) |

## Install

### Linux / macOS

```bash
git clone https://github.com/gasserp/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh                 # install packages + link configs
./install.sh link-only       # only re-link configs
./install.sh packages-only   # only install/refresh packages
```

Supports `brew` (macOS — installs Homebrew if missing), `apt`
(Debian/Ubuntu), `dnf` (Fedora/RHEL), and `pacman` (Arch). VS Code configs
land in `~/Library/Application Support/Code/User` on macOS and
`~/.config/Code/User` on Linux.

What it installs:
`vim`, `git`, `zsh`, `fzf`, `fd`, `ripgrep`, `bat`, `lazygit`, VS Code, Azure
CLI, PowerShell 7, oh-my-posh, Ghostty (macOS + Arch), and the zsh plugins
`zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`
(no oh-my-zsh).

To make zsh your default shell after install:

```bash
chsh -s "$(command -v zsh)"
```

### Windows (PowerShell 7+, run as admin or with Developer Mode on for symlinks)

```powershell
git clone https://github.com/gasserp/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
.\install.ps1                    # install packages + link configs
.\install.ps1 -Mode LinkOnly
.\install.ps1 -Mode PackagesOnly
```

Uses `winget` to install: PowerShell 7, VS Code, Vim, Azure CLI, fzf,
oh-my-posh, lazygit, Git, fd, ripgrep, bat. Also installs the `PSReadLine`
and `PSFzf` PowerShell modules.

If `winget` can't create symlinks, the script falls back to copying. Enable
[Developer Mode](https://learn.microsoft.com/windows/apps/get-started/enable-your-device-for-development)
or run from an elevated shell to get real symlinks.

#### Troubleshooting: "new terminal still looks vanilla" / aliases like `cdc`/`ccd` missing

The installer links the profile into your real `Documents\PowerShell` (and
`Documents\WindowsPowerShell`) folder via `[Environment]::GetFolderPath('MyDocuments')`,
which accounts for **OneDrive Known Folder Move** redirecting `Documents` to
somewhere like `C:\Users\<you>\OneDrive\Documents` (or a localized name like
`Dokumente`). If you ran an older version of this script, it may have written
to the unredirected `$HOME\Documents\PowerShell` instead — a path PowerShell
never reads — leaving your real `$PROFILE` untouched.

To debug:

- `$PROFILE` shows the exact file PowerShell loads for this host. Run
  `Test-Path $PROFILE` and `Get-Content $PROFILE` to confirm it's the
  dotfiles version, not stale content.
- Check Windows Terminal's default profile (Settings > Startup > Default
  profile) — if it's "Windows PowerShell" instead of "PowerShell", that's a
  different shell with its own `$PROFILE`.
- If `oh-my-posh`, `fzf`, etc. report as not found, fully restart your
  terminal app (or sign out/in) — winget's PATH changes don't apply to
  already-open shells or shells spawned from a stale environment.
- If the profile errors with "running scripts is disabled", re-run
  `.\install.ps1 -Mode LinkOnly` (it sets the `CurrentUser` execution policy
  to `RemoteSigned`), or run `Set-ExecutionPolicy -Scope CurrentUser
  RemoteSigned`.

## Repo layout

```
.
├── install.sh                        # Linux bootstrapper
├── install.ps1                       # Windows bootstrapper
├── vim/vimrc
├── vscode/{settings.json,keybindings.json,extensions.txt}
├── powershell/Microsoft.PowerShell_profile.ps1
├── azcli/config
├── zsh/{zshrc,aliases.zsh}
├── fzf/fzf.zsh
├── oh-my-posh/dotfiles.omp.json
├── lazygit/config.yml
├── ghostty/config
└── claude/{statusline-command.sh,statusline-helper.js}
```

## Adding a new tool

1. Create a directory at the repo root (`tool-name/`).
2. Drop the example config inside.
3. Add a `link …` line for it in `install.sh` (`create_links`) and
   `install.ps1` (`Create-Links`).
4. If it needs to be installed, add it to the package lists in both scripts.
