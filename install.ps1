# Hacker terminal setup: Windows Terminal theme + Kali-style oh-my-posh prompt + Anonymous wallpaper.
# Safe to re-run. Backs up anything it overwrites (*.bak-<timestamp>).
param(
    [string]$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    [switch]$SkipApps,
    [switch]$SkipProfile
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

Write-Host ''
Write-Host 'Done. Open a new Windows Terminal window to see the hacker theme.' -ForegroundColor Green
