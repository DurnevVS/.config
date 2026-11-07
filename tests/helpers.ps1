param(
    [Parameter(Mandatory = $true)][string]$SuitePath,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$TemporaryRoot
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $RepositoryRoot 'powershell/installer-functions.ps1')

function Get-TestFiles {
    param([object]$InputData)
    @($InputData.globs | ForEach-Object {
        Get-ChildItem -Path (Join-Path $RepositoryRoot $_) -File -ErrorAction SilentlyContinue
    } | Sort-Object FullName -Unique)
}

function New-TestFixture {
    param([string]$Root, [object]$Files)
    $null = New-Item -ItemType Directory -Path $Root -Force
    if ($null -ne $Files) {
        foreach ($file in $Files.PSObject.Properties) {
            $path = Join-Path $Root $file.Name
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
            [IO.File]::WriteAllText($path, [string]$file.Value)
        }
    }
}

function Invoke-TestCase {
    param([object]$Case)
    $data = $Case.input
    $caseRoot = Join-Path $TemporaryRoot $Case.id
    switch ($Case.action) {
        'git_ignore' {
            $null = New-Item -ItemType Directory -Path $caseRoot -Force
            Copy-Item -LiteralPath (Join-Path $RepositoryRoot '.gitignore') -Destination $caseRoot
            & git -C $caseRoot init --quiet
            if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the ignore-rule fixture.' }
            $public = @(Get-DotfilesConfigurationPaths) + @('.gitignore', 'README.md', 'install.ps1', 'tests.toml', 'tests/run.py', 'tests/helpers.ps1')
            # Git's --stdin treats PowerShell's Windows CRLF as part of each name.
            $ignoreArguments = @('-C', $caseRoot, 'check-ignore', '--no-index', '--') + @($data.private_paths) + $public
            $ignored = @(& git @ignoreArguments)
            if ($LASTEXITCODE -notin @(0, 1)) { throw 'git check-ignore failed.' }
            return [ordered]@{
                exposed_private = @($data.private_paths | Where-Object { $_ -notin $ignored })
                ignored_public = @($public | Where-Object { $_ -in $ignored })
            }
        }
        'repository_files' {
            $public = @(Get-DotfilesConfigurationPaths) + @('.gitignore', 'README.md', 'install.ps1', 'tests.toml', 'tests/run.py', 'tests/helpers.ps1')
            $actual = @(& git -C $RepositoryRoot ls-files --cached --others --exclude-standard)
            if ($LASTEXITCODE -ne 0) { throw 'Could not list the publication files.' }
            return [ordered]@{
                missing = @($public | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RepositoryRoot $_) -PathType Leaf) })
                ignored = @($public | Where-Object { $_ -notin $actual })
                unexpected = @($actual | Where-Object { $_ -notin $public })
            }
        }
        'call' {
            if ($data.function -notmatch '^Get-Dotfiles[A-Za-z]+$') {
                throw 'Only installer query functions can be called by this handler.'
            }
            $parameters = @{}
            if ($null -ne $data.parameters) {
                foreach ($property in $data.parameters.PSObject.Properties) {
                    $parameters[$property.Name] = $property.Value
                }
            }
            $iterations = 1
            if ($data.repeat) { $iterations = [int]$data.repeat }
            for ($iteration = 0; $iteration -lt $iterations; $iteration++) {
                $value = & $data.function @parameters
                if ($data.feedback_parameter) {
                    $parameters[$data.feedback_parameter] = $value
                }
            }
            if ($data.select) { $value = @($value | ForEach-Object { $_.($data.select) }) }
            if ($data.sort) { $value = @($value | Sort-Object) }
            if ($data.array) { $value = @($value | Where-Object { $null -ne $_ }) }
            if ($data.normalize_newlines) { $value = ([string]$value).Replace("`r`n", "`n") }
            return ,$value
        }
        'copy_plan' {
            $source = Join-Path $caseRoot 'source'
            $destination = Join-Path $caseRoot 'destination'
            New-TestFixture -Root $source -Files $data.files
            if ($data.same_roots) { $destination = $source }
            $plan = @(Get-DotfilesCopyPlan -SourceRoot $source -ConfigRoot $destination)
            $paths = @($plan | ForEach-Object { $_.RelativePath.Replace('\', '/') } | Sort-Object)
            return ,$paths
        }
        'install_config' {
            $source = Join-Path $caseRoot 'source'
            $destination = Join-Path $caseRoot 'destination'
            New-TestFixture -Root $source -Files $data.source_files
            New-TestFixture -Root $destination -Files $data.destination_files
            $snapshots = @(
                for ($iteration = 0; $iteration -lt [int]$data.repeat; $iteration++) {
                    $null = Install-DotfilesConfiguration -SourceRoot $source -ConfigRoot $destination 6>&1
                    $files = [ordered]@{}
                    foreach ($path in $data.watch_paths) {
                        $files[$path] = [IO.File]::ReadAllText((Join-Path $destination $path))
                    }
                    $backups = @(Get-ChildItem -LiteralPath $destination -Recurse -File -Filter $data.backup_pattern | Sort-Object FullName)
                    [ordered]@{
                        files = $files
                        backup_count = $backups.Count
                        backup_contents = @($backups | ForEach-Object { [IO.File]::ReadAllText($_.FullName) })
                    }
                }
            )
            return ,$snapshots
        }
        'native_result' {
            $nativeCode = [long]$data.exit_code
            $commandName = [string]$data.command
            $mockCommand = {
                param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
                $global:LASTEXITCODE = $nativeCode
            }.GetNewClosure()
            Set-Item -Path ('Function:' + $commandName) -Value $mockCommand
            try {
                return Invoke-DotfilesNativeCommand -Command $commandName -Arguments @($data.arguments)
            }
            finally { Remove-Item -LiteralPath ('Function:' + $commandName) }
        }
        'component_confirmation' {
            $answers = New-Object 'System.Collections.Generic.Queue[string]'
            foreach ($answer in $data.answers) { $answers.Enqueue([string]$answer) }
            $prompts = New-Object 'System.Collections.Generic.List[string]'
            function Read-Host {
                param([string]$Prompt)
                $prompts.Add($Prompt)
                if ($answers.Count -eq 0) { throw 'Unexpected confirmation prompt.' }
                $answers.Dequeue()
            }
            $accepted = Confirm-DotfilesComponent -Name 'Posting' -Yes:([bool]$data.yes)
            if ($answers.Count -ne 0) { throw 'Not all supplied answers were used.' }
            return [ordered]@{ accepted = $accepted; prompt_count = $prompts.Count }
        }
        'selective_install' {
            $destination = Join-Path $caseRoot 'destination'
            $applicationData = Join-Path $caseRoot 'appdata'
            $testCatalog = @(Get-DotfilesPackageCatalog)
            $state = @{
                available = @{ winget = $true; posting = $true }
                answers = (New-Object 'System.Collections.Generic.Queue[string]')
                prompts = (New-Object 'System.Collections.Generic.List[string]')
                nativeInstalls = (New-Object 'System.Collections.Generic.List[string]')
                fontInstalled = [bool]$data.font_installed
                fontInstalls = 0
                bootstraps = 0
                profileConfigured = $false
            }
            foreach ($package in $testCatalog) { $state.available[$package.Command] = $true }
            foreach ($command in $data.missing_commands) { $state.available.Remove([string]$command) }
            foreach ($answer in $data.answers) { $state.answers.Enqueue([string]$answer) }
            function Read-Host {
                param([string]$Prompt)
                $state.prompts.Add($Prompt)
                if ($state.answers.Count -eq 0) { throw ('Unexpected installation prompt: ' + $Prompt) }
                $state.answers.Dequeue()
            }
            function Get-Command {
                param([string]$Name, $CommandType, $ErrorAction)
                if ($state.available.ContainsKey($Name)) { [PSCustomObject]@{ Source = ('C:\Tools\' + $Name + '.exe') } }
            }
            function Test-DotfilesPackageInstalled {
                param($Package)
                $state.available.ContainsKey($Package.Command)
            }
            function Update-DotfilesProcessPath { }
            function Install-DotfilesWinGet { $state.bootstraps++; $state.available['winget'] = $true }
            function Test-DotfilesFontInstalled { $state.fontInstalled }
            function Install-DotfilesFont { $state.fontInstalls++; $state.fontInstalled = $true }
            function Install-DotfilesProfile { param($ConfigRoot) $state.profileConfigured = $true }
            function Invoke-DotfilesNativeCommand {
                param([string]$Command, [string[]]$Arguments)
                if ($Command -eq 'winget') {
                    $index = [Array]::IndexOf($Arguments, '--id')
                    if ($index -lt 0) { throw 'WinGet install call has no package ID.' }
                    $id = $Arguments[$index + 1]
                    $package = $testCatalog | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                    if (-not $package) { throw ('Unexpected package: ' + $id) }
                    $state.nativeInstalls.Add($id)
                    $state.available[$package.Command] = $true
                }
                elseif ($Command -eq 'uv' -and ($Arguments -join ' ') -eq 'tool install --python 3.13 posting') {
                    $state.nativeInstalls.Add('posting')
                    $state.available['posting'] = $true
                }
                else { throw ('Unexpected native command: ' + $Command) }
                Get-DotfilesExitStatus -ExitCode 0
            }
            $oldApplicationData = $env:LOCALAPPDATA
            $oldSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol
            try {
                $env:LOCALAPPDATA = $applicationData
                # Run the installation flow with fake applications; file writes
                # remain real, inside this case's temporary config and AppData.
                $messages = @(Invoke-DotfilesInstall -SourceRoot $RepositoryRoot -ConfigRoot $destination -Yes:([bool]$data.yes) -Confirm:$false *>&1)
                if ($state.answers.Count -ne 0) { throw 'Not all supplied installation answers were used.' }
                $fragmentPath = Join-Path $applicationData 'Microsoft\Windows Terminal\Fragments\dotfiles\profile.json'
                $fragmentExists = Test-Path -LiteralPath $fragmentPath -PathType Leaf
                $fontConfigured = $false
                if ($fragmentExists) {
                    $fragment = [IO.File]::ReadAllText($fragmentPath) | ConvertFrom-Json
                    $fontConfigured = ($fragment.profiles[0].font.face -eq 'JetBrainsMono Nerd Font')
                }
                return [ordered]@{
                    prompts = @($state.prompts.ToArray())
                    native_installs = @($state.nativeInstalls.ToArray())
                    winget_bootstraps = $state.bootstraps
                    font_installs = $state.fontInstalls
                    profile_configured = $state.profileConfigured
                    terminal_profile_created = $fragmentExists
                    terminal_font_configured = $fontConfigured
                    configuration_copied = (Test-Path -LiteralPath (Join-Path $destination 'powershell/init.ps1'))
                }
            }
            finally {
                $env:LOCALAPPDATA = $oldApplicationData
                [Net.ServicePointManager]::SecurityProtocol = $oldSecurityProtocol
            }
        }
        'dry_run' {
            $destination = Join-Path $caseRoot 'destination'
            $null = New-Item -ItemType Directory -Path $caseRoot -Force
            $oldPath = $env:PATH
            $nativeCalls = New-Object 'System.Collections.Generic.List[string]'
            $block = {
                param([Parameter(ValueFromRemainingArguments = $true)][object[]]$Arguments)
                $nativeCalls.Add($MyInvocation.MyCommand.Name)
                throw ('Dry run attempted a prohibited command: ' + $MyInvocation.MyCommand.Name)
            }.GetNewClosure()
            $savedFunctions = @{}
            $prohibitedCommands = @($data.prohibited_commands) + @('Read-Host', 'Confirm-DotfilesComponent')
            foreach ($name in $prohibitedCommands) {
                $previous = Get-Item -LiteralPath ('Function:' + $name) -ErrorAction SilentlyContinue
                if ($previous) { $savedFunctions[$name] = $previous.ScriptBlock }
                Set-Item -Path ('Function:' + $name) -Value $block
            }
            try {
                $parameters = @{ ConfigRoot = $destination; WhatIf = $true }
                if ($data.skip_profile) { $parameters.SkipProfile = $true }
                if ($data.yes) { $parameters.Yes = $true }
                $messages = @(& (Join-Path $RepositoryRoot $data.entry) @parameters 6>&1)
                $text = ($messages | ForEach-Object { $_.ToString() }) -join "`n"
                $ids = @([regex]::Matches($text, $data.package_pattern) | ForEach-Object {
                    $_.Groups[1].Value
                } | Sort-Object -Unique)
                return [ordered]@{
                    package_ids = $ids
                    destination_created = (Test-Path -LiteralPath $destination)
                    path_changed = ($oldPath -cne $env:PATH)
                    prohibited_calls = @($nativeCalls.ToArray())
                    font_planned = ($text -match [regex]::Escape($data.font_marker))
                    terminal_planned = ($text -match [regex]::Escape($data.terminal_marker))
                    profile_planned = ($text -match [regex]::Escape($data.profile_marker))
                }
            }
            finally {
                foreach ($name in $prohibitedCommands) {
                    if ($savedFunctions.ContainsKey($name)) {
                        Set-Item -Path ('Function:' + $name) -Value $savedFunctions[$name]
                    }
                    else { Remove-Item -LiteralPath ('Function:' + $name) -ErrorAction SilentlyContinue }
                }
                $env:PATH = $oldPath
            }
        }
        'profile_env' {
            $profileRoot = Join-Path $caseRoot $data.root_name
            $testConfigPrefix = $profileRoot.Replace('\', '/')
            $testRootMarker = [string]$data.root_marker
            $null = New-Item -ItemType Directory -Path $profileRoot -Force
            Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'powershell') -Destination $profileRoot -Recurse
            $errorCount = $Error.Count
            $messages = @(. (Join-Path $profileRoot 'powershell/init.ps1') *>&1)
            $environment = [ordered]@{}
            foreach ($name in $data.environment_names) {
                $actualPath = ([Environment]::GetEnvironmentVariable($name, 'Process')).Replace('\', '/')
                if ($actualPath.StartsWith($testConfigPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                    $actualPath = $testRootMarker + $actualPath.Substring($testConfigPrefix.Length)
                }
                else {
                    throw "Profile path mismatch: '$actualPath' does not start with '$testConfigPrefix'."
                }
                $environment[$name] = $actualPath
            }
            $aliases = [ordered]@{}
            foreach ($name in $data.alias_names) { $aliases[$name] = (Get-Alias -Name $name).Definition }
            return [ordered]@{
                environment = $environment
                aliases = $aliases
                startup_errors = ($Error.Count - $errorCount)
                startup_messages = @($messages | ForEach-Object { $_.ToString() })
            }
        }
        'syntax' {
            $failures = @()
            foreach ($file in (Get-TestFiles $data)) {
                $tokens = $null
                $parseErrors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
                foreach ($parseError in $parseErrors) {
                    $failures += $file.Name + ': ' + $parseError.Message
                }
            }
            return ,$failures
        }
        'no_personal_paths' {
            $matches = @()
            foreach ($file in (Get-TestFiles $data)) {
                $content = [IO.File]::ReadAllText($file.FullName)
                foreach ($needle in $data.needles) {
                    if ($content.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $matches += $file.FullName.Substring($RepositoryRoot.Length + 1).Replace('\', '/') + ': ' + $needle
                    }
                }
            }
            return ,$matches
        }
        default { throw ('Unknown action: ' + $Case.action) }
    }
}

$cases = Get-Content -LiteralPath $SuitePath -Raw -Encoding UTF8 | ConvertFrom-Json
$results = @(
    foreach ($case in $cases) {
        try {
            $output = Invoke-TestCase -Case $case
            [pscustomobject]@{ id = $case.id; output = $output; error = $null }
        }
        catch {
            [pscustomobject]@{ id = $case.id; output = $null; error = $_.Exception.Message }
        }
    }
)
$json = ConvertTo-Json -InputObject $results -Depth 50 -Compress
Write-Output ('DOTFILES_TEST_RESULTS=' + $json)
