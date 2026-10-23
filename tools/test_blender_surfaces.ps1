[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $projectRoot 'artifacts/greystone_surface_20261023'
New-Item -ItemType Directory -Force $outputRoot | Out-Null
$previousQA = $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION
$results = @()
'[]' | Set-Content -LiteralPath (Join-Path $outputRoot 'regression.json') -Encoding utf8
try {
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = '1'
    foreach ($mode in @('TestBlenderSurfaces','TestGreystoneBlender','TestBlenderMigration','TestBlenderMigrationReload','VisualBlenderStory','TestBlenderStoryReload','VisualBlenderCommerce','TestBlenderCommerceReload')) {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        try {
            & (Join-Path $PSScriptRoot 'godot.ps1') -Mode $mode 2>&1 | Tee-Object -FilePath (Join-Path $outputRoot ($mode + '.txt'))
        }
        catch {
            $results += [pscustomobject]@{ mode=$mode; passed=$false; seconds=[math]::Round($timer.Elapsed.TotalSeconds,3) }
            $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputRoot 'regression.json') -Encoding utf8
            throw
        }
        # godot.ps1 checks Process.ExitCode and throws on failure. LASTEXITCODE
        # belongs to any earlier executable and is not this wrapper's result.
        $results += [pscustomobject]@{ mode=$mode; passed=$true; seconds=[math]::Round($timer.Elapsed.TotalSeconds,3) }
        $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputRoot 'regression.json') -Encoding utf8
    }
    foreach ($relative in @('route_result.json','blender_migration_result.json','blender_story_result.json','blender_commerce_result.json')) {
        $source = Join-Path $projectRoot ('artifacts/greystone_blender_20261023/' + $relative)
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $outputRoot -Force }
    }
}
finally {
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = $previousQA
}
