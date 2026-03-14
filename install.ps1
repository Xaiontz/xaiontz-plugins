<#
.SYNOPSIS
    Installs Xaiontz plugins into Cursor's local plugin directory.

.DESCRIPTION
    Reads the marketplace manifest and copies each plugin into
    ~/.cursor/plugins/local/<plugin-name>/ so Cursor picks them up
    without any marketplace publish step.

.PARAMETER Plugins
    Optional list of plugin names to install. When omitted, all
    plugins listed in the marketplace manifest are installed.

.PARAMETER Force
    Overwrite existing plugin directories without prompting.

.EXAMPLE
    .\install.ps1                     # install all plugins
    .\install.ps1 -Plugins sme-stack  # install only sme-stack
    .\install.ps1 -Force              # overwrite without prompting
#>

[CmdletBinding()]
param(
    [string[]]$Plugins,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ManifestPath = Join-Path (Join-Path $RepoRoot '.cursor-plugin') 'marketplace.json'
$LocalPluginsDir = Join-Path (Join-Path (Join-Path $env:USERPROFILE '.cursor') 'plugins') 'local'

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Marketplace manifest not found at $ManifestPath"
    exit 1
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$allPlugins = $manifest.plugins

if ($Plugins -and $Plugins.Length -gt 0) {
    $selected = $allPlugins | Where-Object { $Plugins -contains $_.source }
    $missing = $Plugins | Where-Object { $_ -notin ($allPlugins | ForEach-Object { $_.source }) }
    if ($missing) {
        Write-Error "Unknown plugin(s): $($missing -join ', '). Available: $($allPlugins.source -join ', ')"
        exit 1
    }
} else {
    $selected = $allPlugins
}

if (-not (Test-Path $LocalPluginsDir)) {
    New-Item -ItemType Directory -Path $LocalPluginsDir -Force | Out-Null
    Write-Host "Created $LocalPluginsDir"
}

$installed = @()

foreach ($plugin in $selected) {
    $src = Join-Path (Join-Path $RepoRoot 'plugins') $plugin.source
    $dest = Join-Path $LocalPluginsDir $plugin.source

    if (-not (Test-Path $src)) {
        Write-Warning "Source directory missing for '$($plugin.name)': $src - skipping"
        continue
    }

    if (Test-Path $dest) {
        if ($Force) {
            Remove-Item -Recurse -Force $dest
        } else {
            $answer = Read-Host "'$($plugin.name)' already installed at $dest. Overwrite? [y/N]"
            if ($answer -notin @('y', 'Y', 'yes')) {
                Write-Host "  Skipped $($plugin.name)"
                continue
            }
            Remove-Item -Recurse -Force $dest
        }
    }

    Copy-Item -Recurse -Path $src -Destination $dest
    $installed += $plugin.name
    Write-Host "  Installed $($plugin.name) -> $dest"
}

if ($installed.Count -eq 0) {
    Write-Host "`nNo plugins were installed."
} else {
    Write-Host "`nDone - installed $($installed.Count) plugin(s): $($installed -join ', ')"
    Write-Host "Restart Cursor to pick up changes."
}
