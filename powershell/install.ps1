[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$ConfigRoot = (Join-Path $env:USERPROFILE '.config'),
    [switch]$SkipProfile,
    [switch]$Yes
)

. (Join-Path $PSScriptRoot 'installer-functions.ps1')
Invoke-DotfilesInstall -SourceRoot (Split-Path $PSScriptRoot -Parent) @PSBoundParameters
