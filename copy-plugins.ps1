# Copy built plugin outputs into the local test plugins directory.
# Run from the repo root:  .\copy-plugins.ps1
# Optional -Configuration parameter (default: Debug)
param(
    [string]$Configuration = "Debug"
)

$RepoRoot   = $PSScriptRoot
$SourceBase  = Join-Path $RepoRoot "build\bin\$Configuration"
$DestBase    = Join-Path $RepoRoot "test\plugins"

$Plugins = @(
    @{ Source = "Juice.Plugins.Tests.PluginA"; Dest = "PluginA" }
    @{ Source = "Juice.Plugins.Tests.PluginB"; Dest = "PluginB" }
)

foreach ($plugin in $Plugins) {
    $srcDir  = Join-Path $SourceBase $plugin.Source
    $destDir = Join-Path $DestBase   $plugin.Dest

    if (-not (Test-Path $srcDir)) {
        Write-Warning "Source not found, skipping: $($plugin.Source)"
        continue
    }

    foreach ($tfm in Get-ChildItem -Path $srcDir -Directory) {
        $src  = $tfm.FullName
        $dest = Join-Path $destDir $tfm.Name

        Write-Host "Copying $($plugin.Dest)\$($tfm.Name) ..."
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -Path "$src\*" -Destination $dest -Recurse -Force
    }
}

Write-Host "Done."
