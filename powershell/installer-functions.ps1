# Safe to dot-source: installation starts only in Invoke-DotfilesInstall.

function Get-DotfilesPackageCatalog {
    @(
        @{ Command = 'wt'; Id = 'Microsoft.WindowsTerminal'; Kind = 'command'; Extra = @() },
        @{ Command = 'pwsh'; Id = 'Microsoft.PowerShell'; Kind = 'powershell'; Extra = @() },
        @{ Command = 'git'; Id = 'Git.Git'; Kind = 'git'; Extra = @() },
        @{ Command = 'uv'; Id = 'astral-sh.uv'; Kind = 'command'; Extra = @() },
        @{ Command = 'starship'; Id = 'Starship.Starship'; Kind = 'command'; Extra = @('--scope', 'user', '--installer-type', 'portable') },
        @{ Command = 'gh'; Id = 'GitHub.cli'; Kind = 'command'; Extra = @() },
        @{ Command = 'eza'; Id = 'eza-community.eza'; Kind = 'command'; Extra = @() },
        @{ Command = 'lazygit'; Id = 'JesseDuffield.lazygit'; Kind = 'command'; Extra = @() },
        @{ Command = 'delta'; Id = 'dandavison.delta'; Kind = 'command'; Extra = @() },
        @{ Command = 'micro'; Id = 'zyedidia.micro'; Kind = 'command'; Extra = @() },
        @{ Command = 'glow'; Id = 'charmbracelet.glow'; Kind = 'command'; Extra = @() },
        @{ Command = 'lazydocker'; Id = 'JesseDuffield.Lazydocker'; Kind = 'command'; Extra = @() },
        @{ Command = 'docker'; Id = 'Docker.DockerDesktop'; Kind = 'command'; Extra = @() },
        @{ Command = 'dotnet'; Id = 'Microsoft.DotNet.SDK.10'; Kind = 'sdk'; Extra = @() },
        @{ Command = 'codex'; Id = 'OpenAI.Codex'; Kind = 'command'; Extra = @() },
        @{ Command = 'yazi'; Id = 'sxyazi.yazi'; Kind = 'command'; Extra = @() },
        @{ Command = 'ffmpeg'; Id = 'Gyan.FFmpeg'; Kind = 'command'; Extra = @() },
        @{ Command = '7z'; Id = '7zip.7zip'; Kind = 'command'; Extra = @() },
        @{ Command = 'jq'; Id = 'jqlang.jq'; Kind = 'command'; Extra = @() },
        @{ Command = 'fd'; Id = 'sharkdp.fd'; Kind = 'command'; Extra = @() },
        @{ Command = 'rg'; Id = 'BurntSushi.ripgrep.MSVC'; Kind = 'command'; Extra = @() },
        @{ Command = 'fzf'; Id = 'junegunn.fzf'; Kind = 'command'; Extra = @() },
        @{ Command = 'zoxide'; Id = 'ajeetdsouza.zoxide'; Kind = 'command'; Extra = @() },
        @{ Command = 'magick'; Id = 'ImageMagick.ImageMagick'; Kind = 'command'; Extra = @() },
        @{ Command = 'pdftoppm'; Id = 'oschwartz10612.Poppler'; Kind = 'command'; Extra = @() },
        @{ Command = 'resvg'; Id = 'linebender.resvg'; Kind = 'command'; Extra = @() }
    ) | ForEach-Object { [PSCustomObject]$_ }
}

function Confirm-DotfilesComponent {
    param([Parameter(Mandatory = $true)][string]$Name, [switch]$Yes)
    if ($Yes) { return $true }
    while ($true) {
        $answer = [string](Read-Host -Prompt "Install ${Name}? [y/N]")
        switch -Regex ($answer.Trim()) {
            '^(?i:y|yes|\u0434|\u0434\u0430)$' { return $true }
            '^(?i:|n|no|\u043d|\u043d\u0435\u0442)$' { return $false }
            default { Write-Host 'Enter Y to install, or N / Enter to skip.' }
        }
    }
}

function Get-DotfilesExitStatus {
    param([Parameter(Mandatory = $true)][long]$ExitCode)
    $normalized = $ExitCode -band 4294967295L
    $reboot = $normalized -in @(1641L, 3010L, 2316632329L, 2316632331L)
    $verify = $normalized -in @(2316632107L, 2316632161L, 2316632333L, 2316632334L)
    [PSCustomObject]@{ Success = ($normalized -eq 0 -or $reboot); RebootRequired = $reboot; VerifyInstalled = $verify }
}

function Get-DotfilesProfileLine {
    param([Parameter(Mandatory = $true)][string]$ConfigRoot)
    $init = Join-Path ([IO.Path]::GetFullPath($ConfigRoot)) 'powershell\init.ps1'
    ". '" + $init.Replace("'", "''") + "'"
}

function Get-DotfilesProfileContent {
    param([AllowEmptyString()][string]$Existing = '', [Parameter(Mandatory = $true)][string]$ConfigRoot)
    $line = Get-DotfilesProfileLine -ConfigRoot $ConfigRoot
    if (@($Existing -split '\r?\n' | Where-Object { $_.Trim() -eq $line }).Count -gt 0) { return $Existing }
    $expectedPath = [IO.Path]::GetFullPath((Join-Path $ConfigRoot 'powershell\init.ps1')).Replace('/', '\')
    $profileTokens = $null
    $profileErrors = $null
    $profileAst = [Management.Automation.Language.Parser]::ParseInput($Existing, [ref]$profileTokens, [ref]$profileErrors)
    foreach ($commandAst in $profileAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Dot }, $true)) {
        $pathAst = $commandAst.CommandElements[0]
        if ($pathAst -is [Management.Automation.Language.StringConstantExpressionAst] -or
            ($pathAst -is [Management.Automation.Language.ExpandableStringExpressionAst] -and $pathAst.NestedExpressions.Count -eq 0)) {
            if ($pathAst.Value.Replace('/', '\').Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase)) { return $Existing }
        }
    }
    $result = $Existing
    if ($result.Length -gt 0 -and -not $result.EndsWith("`n")) { $result += [Environment]::NewLine }
    $result + $line + [Environment]::NewLine
}

function Get-DotfilesTerminalFragment {
    param([Parameter(Mandatory = $true)][string]$PowerShellPath, [bool]$UseNerdFont = $true)
    if ($PowerShellPath.Contains('"')) { throw 'PowerShell executable path cannot contain a double quote.' }
    $terminalProfile = [ordered]@{
        guid = '{791f71e0-2f63-4eed-b1f6-2493780f3218}'
        name = 'PowerShell 7 (dotfiles)'
        commandline = '"' + $PowerShellPath + '" -ExecutionPolicy RemoteSigned'
    }
    if ($UseNerdFont) { $terminalProfile.font = [PSCustomObject]@{ face = 'JetBrainsMono Nerd Font' } }
    [PSCustomObject]@{ profiles = @([PSCustomObject]$terminalProfile) }
}

function Get-DotfilesPathEntries {
    param([AllowEmptyString()][string]$ProcessPath = '', [AllowEmptyString()][string]$UserPath = '',
        [AllowEmptyString()][string]$MachinePath = '', [string[]]$AdditionalPaths = @())
    $seen = @{}
    foreach ($part in (@($ProcessPath, $UserPath, $MachinePath) + $AdditionalPaths)) {
        foreach ($entry in ($part -split ';')) {
            $entry = $entry.Trim().Trim('"')
            if (-not $entry) { continue }
            $key = $entry.TrimEnd('\', '/').ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $entry }
        }
    }
}

function Get-DotfilesConfigurationPaths {
    @(
        'starship.toml', 'powershell/init.ps1', 'powershell/install.ps1', 'powershell/installer-functions.ps1',
        'powershell/modules/aliases.ps1', 'powershell/modules/key-bindings.ps1',
        'powershell/modules/pyvenv-switcher.ps1', 'powershell/modules/terminal-tools.ps1',
        'gh/config.yml', 'glow/glow.yml', 'lazydocker/config.yml', 'lazygit/config.yml', 'lazygit/delta.gitconfig',
        'micro/settings.json', 'micro/bindings.json', 'micro/colorschemes/catppuccin-mocha.micro',
        'posting/config.yaml', 'posting/themes/catppuccin-mocha.yaml',
        'yazi/init.lua', 'yazi/yazi.toml', 'yazi/theme.toml', 'yazi/keymap.toml', 'yazi/package.toml',
        'yazi/plugins/preview-arrow.yazi/main.lua',
        'yazi/flavors/catppuccin-mocha.yazi/flavor.toml', 'yazi/flavors/catppuccin-mocha.yazi/tmtheme.xml',
        'yazi/flavors/catppuccin-mocha.yazi/LICENSE', 'yazi/flavors/catppuccin-mocha.yazi/LICENSE-tmtheme',
        'yazi/flavors/catppuccin-mocha.yazi/README.md'
    )
    foreach ($plugin in @('piper', 'toggle-pane', 'yamb')) {
        foreach ($file in @('main.lua', 'LICENSE', 'README.md')) { "yazi/plugins/$plugin.yazi/$file" }
    }
}

function Get-DotfilesCopyPlan {
    param([Parameter(Mandatory = $true)][string]$SourceRoot, [Parameter(Mandatory = $true)][string]$ConfigRoot)
    $source = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/')
    $target = [IO.Path]::GetFullPath($ConfigRoot).TrimEnd('\', '/')
    if ($source.Equals($target, [StringComparison]::OrdinalIgnoreCase)) { return }
    foreach ($relative in (Get-DotfilesConfigurationPaths | Sort-Object -Unique)) {
        $inputPath = [IO.Path]::GetFullPath((Join-Path $source $relative))
        if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { continue }
        $ancestor = $inputPath
        $hasLink = $false
        while ($ancestor.Length -gt $source.Length) {
            if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { $hasLink = $true; break }
            $ancestor = Split-Path -Path $ancestor -Parent
        }
        if ($hasLink) { continue }
        $outputPath = [IO.Path]::GetFullPath((Join-Path $target $relative))
        if (-not $inputPath.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not $outputPath.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Configuration path escapes its root: $relative" }
        [PSCustomObject]@{ Source = $inputPath; Destination = $outputPath; RelativePath = $relative }
    }
}

function Update-DotfilesProcessPath {
    $extra = @((Join-Path $env:USERPROFILE '.local\bin'), (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'), (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'))
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        foreach ($relative in @('PowerShell\7', 'dotnet', 'Git\cmd', 'Git\usr\bin', '7-Zip', 'Docker\Docker\resources\bin', 'Programs\Git\cmd', 'Programs\Git\usr\bin')) {
            $candidate = Join-Path $root $relative
            if (Test-Path -LiteralPath $candidate -PathType Container) { $extra += $candidate }
        }
    }
    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitCommand) { $extra += Join-Path (Split-Path (Split-Path $gitCommand.Source -Parent) -Parent) 'usr\bin' }
    $env:PATH = (Get-DotfilesPathEntries -ProcessPath $env:PATH -UserPath ([Environment]::GetEnvironmentVariable('Path', 'User')) -MachinePath ([Environment]::GetEnvironmentVariable('Path', 'Machine')) -AdditionalPaths $extra) -join ';'
}

function Test-DotfilesPackageInstalled {
    param([Parameter(Mandatory = $true)]$Package)
    $command = Get-Command $Package.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return $false }
    if ($Package.Kind -eq 'powershell') {
        $major = & $command.Source -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.Major'
        return ($LASTEXITCODE -eq 0 -and [string]$major -match '^7$')
    }
    if ($Package.Kind -eq 'sdk') {
        $sdks = & $command.Source --list-sdks
        return ($LASTEXITCODE -eq 0 -and @($sdks | Where-Object { $_ -match '^10\.' }).Count -gt 0)
    }
    if ($Package.Kind -eq 'git') {
        $gitRoot = Split-Path (Split-Path $command.Source -Parent) -Parent
        return ((Test-Path -LiteralPath (Join-Path $gitRoot 'usr\bin\file.exe')) -and (Test-Path -LiteralPath (Join-Path $gitRoot 'usr\bin\sh.exe')))
    }
    return $true
}

function New-DotfilesTemporaryDirectory {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-install-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $path -ErrorAction Stop
    return $path
}

function Remove-DotfilesTemporaryDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $absolute = [IO.Path]::GetFullPath($Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $absolute -Leaf) -notmatch '^dotfiles-install-[a-f0-9]{32}$') { throw "Refusing to remove unexpected temporary path: $absolute" }
    if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force -ErrorAction Stop }
}

function Install-DotfilesWinGet {
    if (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue) { return }
    if ($PSVersionTable.PSEdition -eq 'Core') { Import-Module Appx -UseWindowsPowerShell -ErrorAction Stop }
    else { Import-Module Appx -ErrorAction Stop }
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop }
    catch { Write-Verbose "App Installer registration was unavailable: $($_.Exception.Message)" }
    Update-DotfilesProcessPath
    $appInstaller = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($appInstaller -and (Test-Path -LiteralPath (Join-Path $appInstaller.InstallLocation 'winget.exe'))) {
        $env:PATH = (Get-DotfilesPathEntries -ProcessPath $env:PATH -AdditionalPaths @($appInstaller.InstallLocation)) -join ';'
    }
    if (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue) { return }
    $work = New-DotfilesTemporaryDirectory
    try {
        Write-Host 'Installing WinGet from the official Microsoft GitHub release...'
        $releaseRoot = 'https://github.com/microsoft/winget-cli/releases/latest/download/'
        $bundle = Join-Path $work 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $archive = Join-Path $work 'dependencies.zip'
        Invoke-WebRequest -UseBasicParsing -Uri ($releaseRoot + 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle') -OutFile $bundle -ErrorAction Stop
        Invoke-WebRequest -UseBasicParsing -Uri ($releaseRoot + 'DesktopAppInstaller_Dependencies.zip') -OutFile $archive -ErrorAction Stop
        $dependenciesRoot = Join-Path $work 'dependencies'
        Expand-Archive -LiteralPath $archive -DestinationPath $dependenciesRoot -ErrorAction Stop
        $architecture = $env:PROCESSOR_ARCHITEW6432
        if (-not $architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
        $architecture = switch ($architecture.ToUpperInvariant()) { 'AMD64' { 'x64' }; 'ARM64' { 'arm64' }; 'X86' { 'x86' }; default { throw "Unsupported architecture: $architecture" } }
        $architecturePattern = '(?i)([\\/]' + $architecture + '[\\/]|_' + $architecture + '_|_neutral_)'
        $dependencies = @(Get-ChildItem -LiteralPath $dependenciesRoot -Recurse -File | Where-Object { $_.Extension -in @('.appx', '.msix') -and $_.FullName -match $architecturePattern } | Select-Object -ExpandProperty FullName)
        if ($dependencies.Count -eq 0) { throw "No WinGet dependency packages found for $architecture." }
        Add-AppxPackage -Path $bundle -DependencyPath $dependencies -ErrorAction Stop
        Update-DotfilesProcessPath
        if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) { throw 'WinGet installation completed but winget.exe is unavailable. Reopen PowerShell and rerun install.ps1.' }
    }
    finally { Remove-DotfilesTemporaryDirectory -Path $work }
}

function Invoke-DotfilesNativeCommand {
    param([Parameter(Mandatory = $true)][string]$Command, [string[]]$Arguments = @())
    & $Command @Arguments | Out-Host
    $code = $LASTEXITCODE
    $status = Get-DotfilesExitStatus -ExitCode $code
    if (([long]$code -band 4294967295L) -eq 2316632330L) { throw "$Command requires a Windows restart before installation. Restart Windows and rerun install.ps1 (exit code $code)." }
    if (-not $status.Success -and -not $status.VerifyInstalled) { throw "$Command failed with exit code $code." }
    return $status
}

function Test-DotfilesFontInstalled {
    foreach ($fontKey in @('HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        $fontValues = Get-ItemProperty -LiteralPath $fontKey -ErrorAction SilentlyContinue
        if (-not $fontValues) { continue }
        foreach ($fontProperty in $fontValues.PSObject.Properties) {
            if ($fontProperty.Value -isnot [string] -or (Split-Path $fontProperty.Value -Leaf) -notmatch '^JetBrainsMonoNerdFont-(Regular|Medium|Bold)(?:_\d+)?\.ttf$') { continue }
            $fontPath = $fontProperty.Value
            if (-not [IO.Path]::IsPathRooted($fontPath)) { $fontPath = Join-Path (Join-Path $env:WINDIR 'Fonts') $fontPath }
            if (Test-Path -LiteralPath $fontPath -PathType Leaf) { return $true }
        }
    }
    return $false
}

function Install-DotfilesFont {
    if (Test-DotfilesFontInstalled) { Write-Host 'JetBrainsMono Nerd Font is already installed.'; return }
    $work = New-DotfilesTemporaryDirectory
    try {
        $archive = Join-Path $work 'JetBrainsMono.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $archive -ErrorAction Stop
        $extract = Join-Path $work 'fonts'
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -ErrorAction Stop
        $fonts = @(Get-ChildItem -LiteralPath $extract -Filter '*.ttf' -File -Recurse)
        if ($fonts.Count -eq 0) { throw 'The Nerd Font archive contains no TrueType fonts.' }
        $fontRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $null = New-Item -ItemType Directory -Path $fontRoot -Force
        $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        $null = New-Item -Path $fontKey -Force
        if (-not ('DotfilesNativeFonts' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DotfilesNativeFonts {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResourceEx(string path, uint flags, IntPtr reserved);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
}
'@
        }
        foreach ($font in $fonts) {
            $destination = Join-Path $fontRoot $font.Name
            Copy-Item -LiteralPath $font.FullName -Destination $destination -Force
            $null = New-ItemProperty -Path $fontKey -Name ($font.BaseName + ' (TrueType)') -Value $destination -PropertyType String -Force
            if ([DotfilesNativeFonts]::AddFontResourceEx($destination, 0, [IntPtr]::Zero) -eq 0) { throw "Windows could not register font $($font.Name)." }
        }
        $fontBroadcastResult = [UIntPtr]::Zero
        $null = [DotfilesNativeFonts]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$fontBroadcastResult)
        Write-Host 'JetBrainsMono Nerd Font installed for the current user.'
    }
    finally { Remove-DotfilesTemporaryDirectory -Path $work }
}

function Get-DotfilesFileHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($algorithm.ComputeHash($stream)) }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

function Install-DotfilesConfiguration {
    param([string]$SourceRoot, [string]$ConfigRoot)
    foreach ($item in Get-DotfilesCopyPlan -SourceRoot $SourceRoot -ConfigRoot $ConfigRoot) {
        if (Test-Path -LiteralPath $item.Destination -PathType Leaf) {
            if ((Get-DotfilesFileHash -Path $item.Source) -eq (Get-DotfilesFileHash -Path $item.Destination)) { continue }
            $backup = $item.Destination + '.' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmssffff') + '.bak'
            Copy-Item -LiteralPath $item.Destination -Destination $backup -ErrorAction Stop
            Write-Host "Saved existing configuration: $backup"
        }
        $null = New-Item -ItemType Directory -Path (Split-Path $item.Destination -Parent) -Force
        Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force -ErrorAction Stop
        Unblock-File -LiteralPath $item.Destination -ErrorAction Stop
    }
}

function Install-DotfilesProfile {
    param([Parameter(Mandatory = $true)][string]$ConfigRoot)
    $profilePath = [string](& pwsh -NoLogo -NoProfile -Command '$PROFILE.CurrentUserAllHosts')
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($profilePath) -or -not [IO.Path]::IsPathRooted($profilePath)) { throw 'Could not determine the PowerShell 7 profile path.' }
    $profilePath = $profilePath.Trim()
    $existing = ''
    if (Test-Path -LiteralPath $profilePath) { $existing = [IO.File]::ReadAllText($profilePath) }
    $updated = Get-DotfilesProfileContent -Existing $existing -ConfigRoot $ConfigRoot
    if ($updated -ne $existing) {
        $null = New-Item -ItemType Directory -Path (Split-Path $profilePath -Parent) -Force
        if (Test-Path -LiteralPath $profilePath) { Copy-Item -LiteralPath $profilePath -Destination ($profilePath + '.' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmssffff') + '.bak') -ErrorAction Stop }
        [IO.File]::WriteAllText($profilePath, $updated, (New-Object Text.UTF8Encoding($true)))
    }
    Write-Host "PowerShell 7 profile: $profilePath"
}

function Invoke-DotfilesInstall {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param([Parameter(Mandatory = $true)][string]$SourceRoot, [string]$ConfigRoot = (Join-Path $env:USERPROFILE '.config'), [switch]$SkipProfile, [switch]$Yes)
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $false
    $SourceRoot = [IO.Path]::GetFullPath($SourceRoot)
    $ConfigRoot = [IO.Path]::GetFullPath($ConfigRoot)
    $catalog = @(Get-DotfilesPackageCatalog)
    # Before external commands, downloads, PATH changes and all writes.
    if ($WhatIfPreference) {
        if (-not $Yes) { Write-Output 'PLAN ask before installing each missing application or font (Y: install, N / Enter: skip)' }
        Write-Output 'PLAN bootstrap WinGet if missing'
        foreach ($package in $catalog) { Write-Output "PLAN package $($package.Id)" }
        Write-Output 'PLAN Posting: uv tool install --python 3.13 posting'
        Write-Output 'PLAN font JetBrainsMono Nerd Font'
        foreach ($copy in Get-DotfilesCopyPlan -SourceRoot $SourceRoot -ConfigRoot $ConfigRoot) { Write-Output "PLAN copy $($copy.RelativePath)" }
        if (-not $SkipProfile) { Write-Output "PLAN profile $ConfigRoot" }
        Write-Output 'PLAN terminal PowerShell 7 (dotfiles) with JetBrainsMono Nerd Font'
        return
    }
    if ($env:OS -ne 'Windows_NT') { throw 'This installer requires Windows 10/11 and Windows PowerShell 5.1 or PowerShell 7.' }
    if ([Environment]::OSVersion.Version.Build -lt 17763) { throw 'WinGet requires Windows 10 build 17763 or later.' }
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot 'powershell\init.ps1') -PathType Leaf)) { throw "Missing powershell/init.ps1 in $SourceRoot." }
    $missing = @(Get-DotfilesConfigurationPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $SourceRoot $_) -PathType Leaf) })
    if ($missing.Count -gt 0) { throw ('Missing configuration files: ' + ($missing -join ', ')) }
    if (-not $PSCmdlet.ShouldProcess($ConfigRoot, 'Install terminal applications, dependencies, fonts and PowerShell configuration')) { return }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Update-DotfilesProcessPath
    $winGetReady = [bool](Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)
    if (-not $winGetReady) {
        if (Confirm-DotfilesComponent -Name 'WinGet' -Yes:$Yes) {
            Install-DotfilesWinGet
            $winGetReady = $true
        }
        else { Write-Warning 'WinGet skipped. Applications distributed through WinGet will not be installed.' }
    }
    $rebootRequired = $false
    foreach ($package in $catalog) {
        if (Test-DotfilesPackageInstalled -Package $package) { Write-Host "$($package.Id) is already installed."; continue }
        if (-not $winGetReady) { Write-Host "Skipped $($package.Id): WinGet is unavailable."; continue }
        if (-not (Confirm-DotfilesComponent -Name $package.Id -Yes:$Yes)) { Write-Host "Skipped $($package.Id)."; continue }
        Write-Host "Installing $($package.Id)..."
        $arguments = @('install', '--exact', '--id', $package.Id, '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--silent') + $package.Extra
        $status = Invoke-DotfilesNativeCommand -Command 'winget' -Arguments $arguments
        Update-DotfilesProcessPath
        if ($status.RebootRequired) { $rebootRequired = $true; Write-Warning "$($package.Id) requires a Windows restart." }
        if (-not $status.RebootRequired -and -not (Test-DotfilesPackageInstalled -Package $package)) { throw "$($package.Id) did not become available after installation. Reopen PowerShell and rerun install.ps1." }
    }
    if (-not (Get-Command posting -CommandType Application -ErrorAction SilentlyContinue)) {
        if (Confirm-DotfilesComponent -Name 'Posting' -Yes:$Yes) {
            if (Get-Command uv -CommandType Application -ErrorAction SilentlyContinue) {
                $postingStatus = Invoke-DotfilesNativeCommand -Command 'uv' -Arguments @('tool', 'install', '--python', '3.13', 'posting')
                if (-not $postingStatus.Success) { throw 'Posting installation did not complete successfully.' }
                Update-DotfilesProcessPath
                if (-not (Get-Command posting -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Posting was installed but its executable was not found.' }
            }
            else { Write-Warning 'Posting skipped: uv is unavailable. Rerun the installer and allow uv to install Posting.' }
        }
        else { Write-Host 'Skipped Posting.' }
    }
    if (-not (Test-DotfilesFontInstalled)) {
        if (Confirm-DotfilesComponent -Name 'JetBrainsMono Nerd Font' -Yes:$Yes) { Install-DotfilesFont }
        else { Write-Host 'Skipped JetBrainsMono Nerd Font.' }
    }
    Install-DotfilesConfiguration -SourceRoot $SourceRoot -ConfigRoot $ConfigRoot
    Get-ChildItem -LiteralPath (Join-Path $ConfigRoot 'powershell') -Filter '*.ps1' -File -Recurse | Unblock-File
    $powerShellReady = Test-DotfilesPackageInstalled -Package ($catalog | Where-Object { $_.Kind -eq 'powershell' } | Select-Object -First 1)
    if (-not $SkipProfile) {
        if ($powerShellReady) { Install-DotfilesProfile -ConfigRoot $ConfigRoot }
        else { Write-Warning 'PowerShell 7 is unavailable. Its profile was not configured; rerun after installing PowerShell 7.' }
    }
    if ($powerShellReady -and (Get-Command wt -CommandType Application -ErrorAction SilentlyContinue)) {
        $fragmentPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\dotfiles\profile.json'
        $powerShellPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $fragment = Get-DotfilesTerminalFragment -PowerShellPath $powerShellPath -UseNerdFont (Test-DotfilesFontInstalled) | ConvertTo-Json -Depth 5
        $null = New-Item -ItemType Directory -Path (Split-Path $fragmentPath -Parent) -Force
        if (-not (Test-Path -LiteralPath $fragmentPath) -or [IO.File]::ReadAllText($fragmentPath) -ne $fragment) {
            if (Test-Path -LiteralPath $fragmentPath) { Copy-Item -LiteralPath $fragmentPath -Destination ($fragmentPath + '.' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmssffff') + '.bak') -ErrorAction Stop }
            [IO.File]::WriteAllText($fragmentPath, $fragment, (New-Object Text.UTF8Encoding($false)))
        }
        Write-Host 'Open the PowerShell 7 (dotfiles) profile in Windows Terminal.'
    }
    else { Write-Host 'Terminal profile skipped: PowerShell 7 or Windows Terminal is unavailable.' }
    Write-Host "Configuration installed in $ConfigRoot."
    Write-Host 'GitHub/Codex sign-in and Docker Desktop first-run setup are completed in their applications.'
    if ($rebootRequired) { Write-Warning 'Windows restart required. Restart, then rerun install.ps1 to verify the remaining prerequisites.' }
}
