$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'modules'

# Set config paths before starting programs, and define functions before aliases.
foreach ($moduleName in @('terminal-tools.ps1', 'pyvenv-switcher.ps1', 'aliases.ps1')) {
    . (Join-Path $modulesPath $moduleName)
}

if (-not [Console]::IsOutputRedirected) {
    if (Get-Module PSReadLine) {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
        . (Join-Path $modulesPath 'key-bindings.ps1')
    }

    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell)
    }

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
    }
    if (Get-Command uvx -ErrorAction SilentlyContinue) {
        (& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
    }
}
