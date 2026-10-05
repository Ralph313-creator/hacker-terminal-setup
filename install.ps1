# Hacker terminal setup: Windows Terminal theme + Kali-style oh-my-posh prompt + Anonymous wallpaper
# + Claude Code usage status line + AI usage segment in the prompt (Claude Code, Codex)
# + the same colors and font in the VS Code / Cursor integrated terminal.
# Safe to re-run. Backs up anything it overwrites (*.bak-<timestamp>).
param(
    [string]$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    [string]$ClaudeDir = (Join-Path $HOME '.claude'),
    [switch]$SkipApps,
    [switch]$SkipProfile,
    [switch]$SkipVSCode
)
$ErrorActionPreference = 'Stop'
$files = Join-Path $PSScriptRoot 'files'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Step($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Backup($path) { if (Test-Path $path) { Copy-Item $path "$path.bak-$stamp"; Step "Backed up $path" } }
function SetProp($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

# --- 1. Apps and font ---
if (-not $SkipApps) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    }
    foreach ($id in 'Microsoft.WindowsTerminal', 'JanDeDobbeleer.OhMyPosh') {
        winget list --id $id -e --accept-source-agreements *> $null
        if ($LASTEXITCODE -eq 0) { Step "$id already installed" }
        else {
            Step "Installing $id"
            winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        }
    }
    # Node.js runs the Claude Code status line
    if (Get-Command node -ErrorAction SilentlyContinue) { Step 'Node.js already installed' }
    else {
        Step 'Installing Node.js LTS'
        winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
    }
    # Pick up PATH changes from the installs above
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

    Add-Type -AssemblyName System.Drawing
    $families = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object Name
    if ($families -contains 'JetBrainsMono NF') { Step 'JetBrainsMono Nerd Font already installed' }
    else {
        Step 'Installing JetBrainsMono Nerd Font'
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) { oh-my-posh font install JetBrainsMono } else { oh-my-posh font install JetBrainsMono --user }
    }
}

# --- 2. Prompt config and wallpaper ---
$ompDir = Join-Path $HOME '.config\oh-my-posh'
$wallDir = Join-Path $HOME '.config\terminal'
New-Item -ItemType Directory -Force $ompDir, $wallDir | Out-Null
Copy-Item (Join-Path $files 'hacker.omp.json') $ompDir -Force
Step "Prompt config -> $ompDir\hacker.omp.json"

# AI usage segment for the prompt (reads Claude Code + Codex usage)
$usageDir = Join-Path $HOME '.config\ai-usage'
New-Item -ItemType Directory -Force $usageDir | Out-Null
Copy-Item (Join-Path $files 'ai-usage.js') $usageDir -Force
Step "AI usage reader -> $usageDir\ai-usage.js"

$wall = Join-Path $wallDir 'anonymous-code.jpg'
$localWall = Join-Path $files 'anonymous-code.jpg'
if (Test-Path $localWall) { Copy-Item $localWall $wall -Force }
else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest 'https://pixelz.cc/wp-content/uploads/2019/12/anonymous-mask-code-uhd-4k-wallpaper.jpg' `
        -OutFile $wall -UserAgent 'Mozilla/5.0' -Headers @{ Referer = 'https://pixelz.cc/' } -UseBasicParsing
}
Step "Wallpaper -> $wall"

# --- 3. PowerShell profile (Windows PowerShell 5.1, and PowerShell 7 if present) ---
if (-not $SkipProfile) {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $targets = @(Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { $targets += Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1' }
    foreach ($t in $targets) {
        New-Item -ItemType Directory -Force (Split-Path $t) | Out-Null
        Backup $t
        Copy-Item (Join-Path $files 'Microsoft.PowerShell_profile.ps1') $t -Force
        Step "Profile -> $t"
    }
}

# --- 4. Windows Terminal settings (merged, not replaced) ---
$frag = Get-Content (Join-Path $files 'wt-hacker.json') -Raw | ConvertFrom-Json
if (Test-Path $SettingsPath) {
    Backup $SettingsPath
    # Drop whole-line // comments, which Windows PowerShell's JSON parser rejects
    $raw = (Get-Content $SettingsPath) | Where-Object { $_ -notmatch '^\s*//' }
    $s = ($raw -join "`n") | ConvertFrom-Json
} else {
    Warn "No Windows Terminal settings found yet; creating $SettingsPath"
    New-Item -ItemType Directory -Force (Split-Path $SettingsPath) | Out-Null
    $s = [pscustomobject]@{ '$schema' = 'https://aka.ms/terminal-profiles-schema' }
}

foreach ($p in $frag.globals.PSObject.Properties) { SetProp $s $p.Name $p.Value }
SetProp $s 'schemes' (@($s.schemes | Where-Object { $_ -and $_.name -ne 'Hacker' }) + $frag.scheme)
SetProp $s 'themes' (@($s.themes | Where-Object { $_ -and $_.name -ne 'Hacker' }) + $frag.theme)

if (-not $s.profiles) { SetProp $s 'profiles' ([pscustomobject]@{}) }
elseif ($s.profiles -is [array]) { SetProp $s 'profiles' ([pscustomobject]@{ list = $s.profiles }) }
if (-not $s.profiles.defaults) { SetProp $s.profiles 'defaults' ([pscustomobject]@{}) }
foreach ($p in $frag.defaults.PSObject.Properties) { SetProp $s.profiles.defaults $p.Name $p.Value }

[IO.File]::WriteAllText($SettingsPath, ($s | ConvertTo-Json -Depth 32), $utf8NoBom)
Step "Windows Terminal settings -> $SettingsPath"

# --- 5. Claude Code status line (usage limits, context, cost) ---
New-Item -ItemType Directory -Force $ClaudeDir | Out-Null
$statusScript = Join-Path $ClaudeDir 'statusline.js'
Copy-Item (Join-Path $files 'statusline.js') $statusScript -Force
Step "Status line script -> $statusScript"

$claudeSettings = Join-Path $ClaudeDir 'settings.json'
if (Test-Path $claudeSettings) {
    Backup $claudeSettings
    $c = Get-Content $claudeSettings -Raw | ConvertFrom-Json
} else {
    $c = [pscustomobject]@{}
}
SetProp $c 'statusLine' ([pscustomobject]@{
    type    = 'command'
    command = 'node ' + ($statusScript -replace '\\', '/')
    padding = 0
})
[IO.File]::WriteAllText($claudeSettings, ($c | ConvertTo-Json -Depth 32), $utf8NoBom)
Step "Claude Code status line enabled in $claudeSettings"

# --- 6. VS Code / Cursor integrated terminal (merged, not replaced) ---
if (-not $SkipVSCode) {
    $vs = Get-Content (Join-Path $files 'vscode-hacker.json') -Raw | ConvertFrom-Json

    function Merge-EditorSettings($name, $vsSettings) {
        $raw = if (Test-Path $vsSettings) { (Get-Content $vsSettings) | Where-Object { $_ -notmatch '^\s*//' } } else { $null }
        try {
            $v = if ("$raw".Trim()) { ($raw -join "`n") | ConvertFrom-Json } else { [pscustomobject]@{} }
        } catch {
            # VS Code allows comments and trailing commas that Windows PowerShell can't parse; don't risk breaking the file
            Warn "$name settings could not be read (comments or trailing commas?). Skipped; copy files\vscode-hacker.json in by hand."
            return
        }
        New-Item -ItemType Directory -Force (Split-Path $vsSettings) | Out-Null
        Backup $vsSettings

        foreach ($p in $vs.settings.PSObject.Properties) { SetProp $v $p.Name $p.Value }
        $colorsKey = 'workbench.colorCustomizations'
        if (-not $v.$colorsKey) { SetProp $v $colorsKey ([pscustomobject]@{}) }
        foreach ($p in $vs.colors.PSObject.Properties) { SetProp $v.$colorsKey $p.Name $p.Value }

        $profilesKey = 'terminal.integrated.profiles.windows'
        $defaultKey = 'terminal.integrated.defaultProfile.windows'
        if (-not $v.$profilesKey) { SetProp $v $profilesKey ([pscustomobject]@{}) }
        # A profile that launches wt.exe opens Windows Terminal in its own window instead of inside the editor
        $wtProfiles = @($v.$profilesKey.PSObject.Properties | Where-Object { $_.Value -and "$($_.Value.path)" -match 'wt\.exe' } | ForEach-Object Name)
        foreach ($n in $wtProfiles) { $v.$profilesKey.PSObject.Properties.Remove($n) }
        if ($wtProfiles -contains $v.$defaultKey) { Step "$name default terminal was Windows Terminal (opens outside the editor); replaced" }

        # "Hacker Terminal" profile: PowerShell with the tab named "Hacker Terminal"
        SetProp $v.$profilesKey $vs.profileName $vs.profile
        # Becomes the default unless the user picked another shell (Git Bash, cmd, ...)
        $current = $v.$defaultKey
        if (-not $current -or $current -in @('PowerShell', 'Windows PowerShell', $vs.profileName) -or $wtProfiles -contains $current) {
            SetProp $v $defaultKey $vs.profileName
        } else {
            Warn "$name default terminal is '$current'; left as is. Pick '$($vs.profileName)' from the + dropdown to use it."
        }

        [IO.File]::WriteAllText($vsSettings, ($v | ConvertTo-Json -Depth 32), $utf8NoBom)
        Step "$name terminal theme -> $vsSettings"
    }

    $editors = @(
        @{ Name = 'VS Code'; Data = "$env:APPDATA\Code"; Cmd = 'code'
           Exe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe", "$env:ProgramFiles\Microsoft VS Code\Code.exe" }
        @{ Name = 'VS Code Insiders'; Data = "$env:APPDATA\Code - Insiders"; Cmd = 'code-insiders'
           Exe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\Code - Insiders.exe", "$env:ProgramFiles\Microsoft VS Code Insiders\Code - Insiders.exe" }
        @{ Name = 'Cursor'; Data = "$env:APPDATA\Cursor"; Cmd = 'cursor'
           Exe = @("$env:LOCALAPPDATA\Programs\cursor\Cursor.exe") }
    )
    $found = $false
    foreach ($e in $editors) {
        $user = Join-Path $e.Data 'User'
        $installed = (Test-Path $user) -or @($e.Exe | Where-Object { Test-Path $_ }).Count -gt 0 -or
            [bool](Get-Command $e.Cmd -ErrorAction SilentlyContinue)
        if (-not $installed) { continue }
        $found = $true

        # Default profile. Created if the editor was installed but never opened; it reads the file on first launch
        Merge-EditorSettings $e.Name (Join-Path $user 'settings.json')

        # Other editor profiles that keep their own settings instead of sharing the Default profile's
        $targets = [ordered]@{}
        $storage = Join-Path $user 'globalStorage\storage.json'
        if (Test-Path $storage) {
            try { $profiles = @((Get-Content $storage -Raw | ConvertFrom-Json).userDataProfiles) } catch { $profiles = @() }
            foreach ($p in $profiles) {
                if (-not $p -or ($p.useDefaultFlags -and $p.useDefaultFlags.settings)) { continue }
                $pdir = Join-Path $user "profiles\$($p.location)"
                # Full path, so the folder scan below recognizes it (APPDATA can be an 8.3 short path)
                if (Test-Path $pdir) { $targets[(Join-Path (Get-Item $pdir).FullName 'settings.json')] = "$($e.Name) ($($p.name) profile)" }
            }
        }
        Get-ChildItem (Join-Path $user 'profiles') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $f = Join-Path $_.FullName 'settings.json'
            if ((Test-Path $f) -and -not $targets.Contains($f)) { $targets[$f] = "$($e.Name) ($($_.Name) profile)" }
        }
        foreach ($t in @($targets.Keys)) { Merge-EditorSettings $targets[$t] $t }
    }
    if (-not $found) { Step 'VS Code / Cursor not found; skipped. Re-run the installer after installing one.' }
}

Write-Host ''
Write-Host 'Done. Open a new Windows Terminal window to see the hacker theme.' -ForegroundColor Green
Write-Host 'In VS Code, close any open terminals and press Ctrl+` for a themed one.' -ForegroundColor Green
