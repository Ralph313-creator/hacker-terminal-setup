# One-line install:
#   irm https://raw.githubusercontent.com/Ralph313-creator/hacker-terminal-setup/main/bootstrap.ps1 | iex
# Downloads the repo as a zip and runs install.ps1 from it.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zip = Join-Path $env:TEMP 'hacker-terminal-setup.zip'
$dir = Join-Path $env:TEMP 'hacker-terminal-setup'
Write-Host '[+] Downloading hacker-terminal-setup...' -ForegroundColor Green
Invoke-WebRequest 'https://github.com/Ralph313-creator/hacker-terminal-setup/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
Expand-Archive $zip $dir -Force
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'hacker-terminal-setup-main\install.ps1')
