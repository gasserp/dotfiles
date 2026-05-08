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
| PowerShell 7  | `powershell/Microsoft.PowerShell_profile.ps1`       | `~/.config/powershell/`                | `~\Documents\PowerShell\`                |
| Azure CLI     | `azcli/config`                                      | `~/.azure/config`                      | `%USERPROFILE%\.azure\config`            |
| Zsh (Linux)   | `zsh/zshrc`, `zsh/aliases.zsh`                      | `~/.zshrc`, `~/.config/zsh/aliases.zsh`| —                                        |
| fzf           | `fzf/fzf.zsh`                                       | `~/.config/fzf/fzf.zsh`                | (PSFzf module in the PowerShell profile) |
| oh-my-posh    | `oh-my-posh/dotfiles.omp.json`                      | `~/.config/oh-my-posh/`                | `~\.poshthemes\`                         |
| lazygit       | `lazygit/config.yml`                                | `~/.config/lazygit/config.yml`         | `%APPDATA%\lazygit\config.yml`           |

## Install

### Linux

```bash
git clone https://github.com/gasserp/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh                 # install packages + link configs
./install.sh link-only       # only re-link configs
./install.sh packages-only   # only install/refresh packages
```

Supports `apt` (Debian/Ubuntu), `dnf` (Fedora/RHEL), and `pacman` (Arch).

What it installs:
`vim`, `git`, `zsh`, `fzf`, `fd`, `ripgrep`, `bat`, `lazygit`, VS Code, Azure
CLI, PowerShell 7, oh-my-posh, and the zsh plugins
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
└── lazygit/config.yml
```

## Adding a new tool

1. Create a directory at the repo root (`tool-name/`).
2. Drop the example config inside.
3. Add a `link …` line for it in `install.sh` (`create_links`) and
   `install.ps1` (`Create-Links`).
4. If it needs to be installed, add it to the package lists in both scripts.
