[CmdletBinding()]
param([switch]$SkipExistingRegression)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
$previousIsolation = $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION
try {
    # First create the completed historical fixture using the existing suite.
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = $null
    if (-not $SkipExistingRegression) { & "$PSScriptRoot/test_g06.ps1" -IsolateJoypadMotion }
    & "$PSScriptRoot/godot.ps1" -Mode TestBlenderBoundary
    try {
        $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = '1'
        foreach ($mode in @('TestGreystoneBlender', 'TestBlenderMigration', 'TestBlenderMigrationReload',
                'VisualBlenderNPC', 'VisualBlenderStory', 'TestBlenderStoryReload', 'VisualBlenderCommerce', 'TestBlenderCommerceReload')) {
            & "$PSScriptRoot/godot.ps1" -Mode $mode
        }
    } finally {
        $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = $previousIsolation
    }
} finally {
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = $previousIsolation
    Pop-Location
}
