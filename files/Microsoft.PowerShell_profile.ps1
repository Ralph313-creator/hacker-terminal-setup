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

    $e = [char]27
    Set-PSReadLineOption -Colors @{
        Command   = "$e[38;2;57;255;20m"
        Parameter = "$e[38;2;0;200;50m"
        String    = "$e[38;2;228;255;122m"
        Variable  = "$e[38;2;157;255;176m"
        Number    = "$e[38;2;198;224;0m"
        Operator  = "$e[38;2;92;219;149m"
        Keyword   = "$e[38;2;0;217;126m"
        Type      = "$e[38;2;168;240;180m"
        Member    = "$e[38;2;157;255;176m"
        Comment   = "$e[38;2;47;90;56m"
        Error     = "$e[38;2;255;85;85m"
    }
}
