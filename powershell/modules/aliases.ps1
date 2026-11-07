function Invoke-Eza { eza --icons=always --all $args }
function Invoke-Yazi {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        yazi @args --cwd-file="$tmp"
        $cwd = Get-Content -LiteralPath $tmp -Encoding UTF8 -Raw
        if (-not [String]::IsNullOrWhiteSpace($cwd)) {
            $cwd = $cwd.TrimEnd("`r", "`n")
            if ($cwd -ne $PWD.Path) {
                Set-Location -LiteralPath $cwd
                Set-Venv
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}

Set-Alias -Name ls -Value Invoke-Eza -Option AllScope
Set-Alias -Name e -Value Invoke-Yazi
Set-Alias -Name y -Value Invoke-Yazi
Set-Alias -Name cd -Value Set-LocationVenv -Option AllScope
Set-Alias -Name ed -Value micro
Set-Alias -Name lg -Value lazygit
Set-Alias -Name lzd -Value lazydocker
