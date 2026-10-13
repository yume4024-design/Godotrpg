[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $projectRoot 'builds/windows'
$required = @('ProjectCrystal.exe', 'ProjectCrystal.pck')
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $buildRoot $name))) { throw "Export first: $name is missing." }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/PLAYTEST_GUIDE.md') -Destination (Join-Path $buildRoot 'README.md')
$credits = Get-Content -LiteralPath (Join-Path $projectRoot 'docs/ASSET_CREDITS.md') -Raw
# Design reports remain in the source project; avoid dangling links in the ZIP.
$credits = [regex]::Replace($credits, '\[([^\]]+)\]\(([^)]+)\)', '$1（詳見原始專案文件）')
$credits | Set-Content -LiteralPath (Join-Path $buildRoot 'ASSET_CREDITS.md') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/GODOT_LICENSES.txt') -Destination (Join-Path $buildRoot 'GODOT_LICENSES.txt')
$manifest = Get-ChildItem -LiteralPath $buildRoot -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
}
$manifest | Set-Content -LiteralPath (Join-Path $buildRoot 'SHA256SUMS.txt') -Encoding utf8
$zipPath = Join-Path $projectRoot 'builds/ProjectCrystal-0.6.0-windows-x64.zip'
Compress-Archive -Path (Join-Path $buildRoot '*') -DestinationPath $zipPath -Force
Get-Item -LiteralPath $zipPath | Select-Object FullName, Length
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
