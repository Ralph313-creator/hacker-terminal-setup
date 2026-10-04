# Hacker prompt + syntax colors - only inside Windows Terminal (legacy console can't render Nerd Font glyphs)
# Previous Neon setup: Microsoft.PowerShell_profile.ps1.neon-backup
if ($env:WT_SESSION) {
    oh-my-posh init powershell --config "$HOME\.config\oh-my-posh\hacker.omp.json" | Invoke-Expression

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
