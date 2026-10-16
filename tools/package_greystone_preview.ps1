[CmdletBinding()]
param([string]$BuildDirectory = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $latest = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'builds/greystone-preview') -Directory |
        Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) { throw 'Run ExportGreystonePreview first.' }
    $BuildDirectory = $latest.FullName
}
foreach ($name in @('ProjectCrystal.exe','ProjectCrystal.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $BuildDirectory $name) -PathType Leaf)) { throw "Missing $name" }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/GREYSTONE_PREVIEW_GUIDE.md') -Destination (Join-Path $BuildDirectory 'README.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/GODOT_LICENSES.txt') -Destination (Join-Path $BuildDirectory 'GODOT_LICENSES.txt')
$credits = Get-Content -LiteralPath (Join-Path $projectRoot 'docs/ASSET_CREDITS.md') -Raw
[regex]::Replace($credits,'\[([^\]]+)\]\((?!https?://)([^)]+)\)','$1（詳見原始專案文件）') |
    Set-Content -LiteralPath (Join-Path $BuildDirectory 'ASSET_CREDITS.md') -Encoding utf8
$names = @('ProjectCrystal.exe','ProjectCrystal.pck','README.md','ASSET_CREDITS.md','GODOT_LICENSES.txt')
$manifest = foreach ($name in $names) {
    '{0}  {1}' -f (Get-FileHash -LiteralPath (Join-Path $BuildDirectory $name) -Algorithm SHA256).Hash.ToLowerInvariant(),$name
}
$manifest | Set-Content -LiteralPath (Join-Path $BuildDirectory 'SHA256SUMS.txt') -Encoding utf8
$names += 'SHA256SUMS.txt'
$archive = Join-Path $projectRoot ('builds/ProjectCrystal-G06-preview-{0}-windows-x64.zip' -f (Split-Path $BuildDirectory -Leaf))
if (Test-Path -LiteralPath $archive) { throw 'Preview archive exists; preserve it and export a new timestamp first.' }
$files = $names | ForEach-Object { Join-Path $BuildDirectory $_ }
Compress-Archive -LiteralPath $files -DestinationPath $archive
Get-Item -LiteralPath $archive | Select-Object FullName,Length
Get-FileHash -LiteralPath $archive -Algorithm SHA256
