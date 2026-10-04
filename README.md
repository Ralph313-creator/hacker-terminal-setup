# Hacker Terminal Setup

Green-on-black Windows Terminal theme with a Kali-style prompt and an Anonymous mask wallpaper.

```
┌──(Administrator㉿Server)-[~\Desktop]
└─#
```

## Install on a new PC

Open **PowerShell** and run:

```powershell
winget install GitHub.cli
```

Close PowerShell, open a new window, then:

```powershell
gh auth login
gh repo clone Ralph313-creator/hacker-terminal-setup $HOME\hacker-terminal-setup
& $HOME\hacker-terminal-setup\install.cmd
```

Open a new Windows Terminal window when it finishes.

The installer:
- installs Windows Terminal, oh-my-posh and the JetBrainsMono Nerd Font (skips anything already installed)
- copies the prompt to `~\.config\oh-my-posh\hacker.omp.json` and the wallpaper to `~\.config\terminal\anonymous-code.jpg`
- installs the PowerShell profile (prompt + green syntax colors)
- merges the Hacker scheme/theme into Windows Terminal's settings, keeping your existing profiles

Anything it overwrites is backed up next to the original as `*.bak-<timestamp>`. Safe to re-run.

## Tweaks

All in Windows Terminal's `settings.json` (Settings → Open JSON file), under `profiles.defaults`:

| Want | Change |
|---|---|
| Darker / brighter wallpaper | `"backgroundImageOpacity": 0.4` (lower = darker, `1` = full) |
| Plain black, no wallpaper | delete the four `backgroundImage...` lines |
| No CRT scanlines | `"experimental.retroTerminalEffect": false` |

## Files

| File | What it is |
|---|---|
| `install.ps1` / `install.cmd` | Installer (double-click `install.cmd`) |
| `files/wt-hacker.json` | Color scheme, window theme and profile defaults that get merged into Windows Terminal |
| `files/hacker.omp.json` | oh-my-posh prompt |
| `files/Microsoft.PowerShell_profile.ps1` | PowerShell profile |
| `files/anonymous-code.jpg` | Wallpaper ([source](https://pixelz.cc/images/anonymous-mask-code-uhd-4k-wallpaper/)) |
| `files/settings.reference.json` | Full Windows Terminal settings from the original PC, for reference |
