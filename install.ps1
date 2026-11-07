<#
.SYNOPSIS
Installs the terminal applications, dependencies and configuration on Windows.
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Yes
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [string]$ConfigRoot = (Join-Path $env:USERPROFILE '.config'),
    [switch]$SkipProfile,
    [switch]$Yes
)

& (Join-Path $PSScriptRoot 'powershell\install.ps1') @PSBoundParameters
