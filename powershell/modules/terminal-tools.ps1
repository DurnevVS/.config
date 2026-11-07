# Editors and preview helpers for the terminal toolchain.
$cliConfigRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:XDG_CONFIG_HOME = $cliConfigRoot
$env:CODEX_HOME = Join-Path $cliConfigRoot 'codex'
$env:YAZI_CONFIG_HOME = Join-Path $cliConfigRoot 'yazi'
$env:GLOW_CONFIG_HOME = Join-Path $cliConfigRoot 'glow'
$env:GH_CONFIG_DIR = Join-Path $cliConfigRoot 'gh'
$env:MICRO_CONFIG_HOME = Join-Path $cliConfigRoot 'micro'
$env:STARSHIP_CONFIG = Join-Path $cliConfigRoot 'starship.toml'
$env:POSTING_CONFIG_FILE = Join-Path $cliConfigRoot 'posting\config.yaml'
$env:POSTING_THEME_DIRECTORY = Join-Path $cliConfigRoot 'posting\themes'
$env:DOTFILES_DELTA_CONFIG = (Join-Path $cliConfigRoot 'lazygit\delta.gitconfig').Replace('\', '/')
$env:EDITOR = 'micro'
$env:VISUAL = 'micro'
$env:MICRO_TRUECOLOR = '1'
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$gitCandidates = @()
if ($gitCommand) {
    $gitInstallRoot = Split-Path -Parent (Split-Path -Parent $gitCommand.Source)
    $gitCandidates += Join-Path $gitInstallRoot 'usr\bin'
}
foreach ($installRoot in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:USERPROFILE)) {
    if ($installRoot) { $gitCandidates += Join-Path $installRoot 'Git\usr\bin' }
}
if ($env:LOCALAPPDATA) {
    $gitCandidates += Join-Path $env:LOCALAPPDATA 'Programs\Git\usr\bin'
}
foreach ($gitHelpers in $gitCandidates) {
    $gitFile = Join-Path $gitHelpers 'file.exe'
    if ((Test-Path -LiteralPath $gitFile -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $gitHelpers 'sh.exe') -PathType Leaf)) {
        $env:YAZI_FILE_ONE = $gitFile
        if ($gitHelpers -notin ($env:PATH -split ';')) {
            $env:PATH += ";$gitHelpers"
        }
        break
    }
}
