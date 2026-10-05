# Color themes for the hacker terminal: Windows Terminal, plus the VS Code / Cursor "Hacker Terminal".
# The prompt, typing colors and Claude Code status line use the terminal's 16 colors, so they follow.
#   theme          list the themes
#   theme amber    switch to Amber
# Themes are defined in themes.json next to this script.
param(
    [string]$Name,
    [string]$SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    [switch]$SkipEditors
)
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Step($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function SetProp($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
# Drop whole-line // comments, which Windows PowerShell's JSON parser rejects
function Read-Json($path) { ((Get-Content $path -Encoding UTF8) | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json }
function Write-Json($path, $obj) { [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 32), $utf8NoBom) }

$themes = Get-Content (Join-Path $PSScriptRoot 'themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @($themes.PSObject.Properties | ForEach-Object Name)
$schemeNames = @($keys | ForEach-Object { $themes.$_.scheme.name })
$wt = if (Test-Path $SettingsPath) { Read-Json $SettingsPath }

if (-not $Name) {
    $current = if ($wt -and $wt.profiles.defaults) { $wt.profiles.defaults.colorScheme }
    $e = [char]27
    Write-Host ''
    foreach ($k in $keys) {
        $t = $themes.$k
        $rgb = ($t.frame.TrimStart('#') -split '(..)' -ne '' | ForEach-Object { [Convert]::ToInt32($_, 16) }) -join ';'
        $mark = if ($t.scheme.name -eq $current) { '>' } else { ' ' }
        Write-Host (" $mark $e[38;2;${rgb}m{0,-10}$e[0m {1}" -f $k, $t.label)
    }
    Write-Host ''
    Write-Host 'Switch with: theme <name>   (e.g. theme amber)'
    return
}

$Name = $Name.ToLower()
if ($keys -notcontains $Name) { throw "Unknown theme '$Name'. Themes: $($keys -join ', ')" }
$t = $themes.$Name

# --- Windows Terminal: add every theme's color scheme and window theme, select this one ---
if ($wt) {
    $windowThemes = foreach ($k in $keys) {
        $s = $themes.$k
        [pscustomobject]@{
            name   = $s.scheme.name
            tab    = [pscustomobject]@{ background = 'terminalBackground'; iconStyle = 'monochrome'; showCloseButton = 'hover'; unfocusedBackground = '#00000000' }
            tabRow = [pscustomobject]@{ background = "$($s.scheme.background)FF"; unfocusedBackground = "$($s.scheme.background)FF" }
            window = [pscustomobject]@{ applicationTheme = 'dark'; 'experimental.rainbowFrame' = $false; frame = $s.frame; unfocusedFrame = $s.unfocusedFrame; useMica = $false }
        }
    }
    SetProp $wt 'schemes' (@($wt.schemes | Where-Object { $_ -and $_.name -notin $schemeNames }) + @($keys | ForEach-Object { $themes.$_.scheme }))
    SetProp $wt 'themes' (@($wt.themes | Where-Object { $_ -and $_.name -notin $schemeNames }) + @($windowThemes))
    SetProp $wt 'theme' $t.scheme.name
    if (-not $wt.profiles) { SetProp $wt 'profiles' ([pscustomobject]@{}) }
    elseif ($wt.profiles -is [array]) { SetProp $wt 'profiles' ([pscustomobject]@{ list = $wt.profiles }) }
    if (-not $wt.profiles.defaults) { SetProp $wt.profiles 'defaults' ([pscustomobject]@{}) }
    SetProp $wt.profiles.defaults 'colorScheme' $t.scheme.name
    Write-Json $SettingsPath $wt
    Step "Windows Terminal -> $($t.scheme.name)"
} else {
    Warn "Windows Terminal settings not found ($SettingsPath); skipped"
}

# --- VS Code / Cursor: recolor the integrated terminal where the installer set it up ---
$vsColors = [ordered]@{
    'terminal.background' = 'background'; 'terminal.foreground' = 'foreground'
    'terminalCursor.foreground' = 'cursorColor'; 'terminal.selectionBackground' = 'selectionBackground'
    'terminal.ansiBlack' = 'black'; 'terminal.ansiRed' = 'red'; 'terminal.ansiGreen' = 'green'; 'terminal.ansiYellow' = 'yellow'
    'terminal.ansiBlue' = 'blue'; 'terminal.ansiMagenta' = 'purple'; 'terminal.ansiCyan' = 'cyan'; 'terminal.ansiWhite' = 'white'
    'terminal.ansiBrightBlack' = 'brightBlack'; 'terminal.ansiBrightRed' = 'brightRed'; 'terminal.ansiBrightGreen' = 'brightGreen'
    'terminal.ansiBrightYellow' = 'brightYellow'; 'terminal.ansiBrightBlue' = 'brightBlue'; 'terminal.ansiBrightMagenta' = 'brightPurple'
    'terminal.ansiBrightCyan' = 'brightCyan'; 'terminal.ansiBrightWhite' = 'brightWhite'
}
$foregrounds = @($keys | ForEach-Object { $themes.$_.scheme.foreground })
$colorsKey = 'workbench.colorCustomizations'
foreach ($app in @('Code', 'Code - Insiders', 'Cursor') | Where-Object { -not $SkipEditors }) {
    $user = Join-Path $env:APPDATA "$app\User"
    $files = @(Join-Path $user 'settings.json') + @(Get-ChildItem (Join-Path $user 'profiles') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'settings.json' })
    foreach ($f in $files) {
        if (-not (Test-Path $f)) { continue }
        try { $v = Read-Json $f } catch {
            if (Select-String -Path $f -SimpleMatch 'Hacker Terminal' -Quiet) { Warn "$f could not be read (comments or trailing commas?); skipped" }
            continue
        }
        if (-not $v) { continue }
        # Set up by the installer: has the Hacker Terminal profile, or one of these themes' terminal colors
        $ours = ($v.'terminal.integrated.profiles.windows' -and $v.'terminal.integrated.profiles.windows'.PSObject.Properties['Hacker Terminal']) -or
            ($v.$colorsKey -and $v.$colorsKey.'terminal.foreground' -in $foregrounds)
        if (-not $ours) { continue }
        if (-not $v.$colorsKey) { SetProp $v $colorsKey ([pscustomobject]@{}) }
        foreach ($k in $vsColors.Keys) { SetProp $v.$colorsKey $k $t.scheme.($vsColors[$k]) }
        Write-Json $f $v
        Step "Editor terminal -> $f"
    }
}
