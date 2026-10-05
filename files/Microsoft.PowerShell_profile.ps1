# Hacker prompt + syntax colors - only inside Windows Terminal (legacy console can't render Nerd Font glyphs)
# Previous Neon setup: Microsoft.PowerShell_profile.ps1.neon-backup
if ($env:WT_SESSION) {
    oh-my-posh init powershell --config "$HOME\.config\oh-my-posh\hacker.omp.json" | Invoke-Expression

    # AI usage segment (Claude Code, Codex): refresh $env:AI_USAGE before oh-my-posh draws each prompt.
    # oh-my-posh reads the last command's success from NVS_ORIGINAL_LASTEXECUTIONSTATUS when set,
    # so the error indicator still reflects your command, not the node call.
    $global:AiUsageScript = "$HOME\.config\ai-usage\ai-usage.js"
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $global:AiUsageScript)) {
        $global:OmpPrompt = $function:prompt
        function global:prompt {
            $global:NVS_ORIGINAL_LASTEXECUTIONSTATUS = $?
            $exitCode = $global:LASTEXITCODE
            # node writes UTF-8; Windows PowerShell would otherwise decode it with the legacy console code page
            $consoleEncoding = [Console]::OutputEncoding
            [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
            $level, $env:AI_USAGE = ((node $global:AiUsageScript 2>$null) -join '') -split '\|', 2
            [Console]::OutputEncoding = $consoleEncoding
            $env:AI_USAGE_LEVEL = $level
            $global:LASTEXITCODE = $exitCode
            & $global:OmpPrompt
        }
    }

    # The terminal's 16 colors (not fixed RGB), so typing colors follow the color theme
    $e = [char]27
    Set-PSReadLineOption -Colors @{
        Command   = "$e[92m"   # bright green
        Parameter = "$e[32m"   # green
        String    = "$e[93m"   # bright yellow
        Variable  = "$e[96m"   # bright cyan
        Number    = "$e[33m"   # yellow
        Operator  = "$e[94m"   # bright blue
        Keyword   = "$e[36m"   # cyan
        Type      = "$e[37m"   # white
        Member    = "$e[96m"   # bright cyan
        Comment   = "$e[90m"   # bright black
        Error     = "$e[91m"   # bright red
    }
}

# Color themes: `theme` lists them, `theme amber` switches (Windows Terminal and VS Code / Cursor)
function theme([string]$Name) { & "$HOME\.config\terminal\theme.ps1" $Name }
Register-ArgumentCompleter -CommandName theme -ParameterName Name -ScriptBlock {
    param($command, $parameter, $word)
    (Get-Content "$HOME\.config\terminal\themes.json" -Raw | ConvertFrom-Json).PSObject.Properties.Name | Where-Object { $_ -like "$word*" }
}
