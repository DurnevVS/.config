function Set-Venv {
    $venvPath = Join-Path -Path $PWD -ChildPath ".venv"
    if (Test-Path -Path $venvPath) {
        $Global:parentVenvPath = $PWD
        . $venvPath/Scripts/Activate.ps1
    } 
    else {
        if ((Get-Command deactivate -ErrorAction Ignore) -and $null -ne $parentVenvPath -and
            -not ($PWD.Path.Equals($parentVenvPath.Path, [StringComparison]::OrdinalIgnoreCase) -or
                  $PWD.Path.StartsWith($parentVenvPath.Path.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase))) {
            $parentVenvPath = $null
            deactivate
        }
    }
    
}
function Set-LocationVenv {
    Set-Location @args
    Set-Venv
}

Set-Venv
