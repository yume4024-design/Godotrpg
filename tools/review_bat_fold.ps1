[CmdletBinding()]
param([switch]$Controller)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$taskFolder = Join-Path $taskRoot 'artifacts/asset_a03/crystal_bat_manual_v3'
New-Item -ItemType Directory -Force (Join-Path $taskFolder 'profile'), (Join-Path $taskFolder 'local') | Out-Null
$taskPreviousAppData, $taskPreviousLocal = $env:APPDATA, $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $taskFolder 'profile'
    $env:LOCALAPPDATA = Join-Path $taskFolder 'local'
    if ($Controller) {
        & $taskEngine --path $taskRoot --log-file (Join-Path $taskFolder 'controller.log') --script res://tests/rigged_enemy_controller_test.gd -- --asset=crystal_bat_manual
    } else {
        & $taskEngine --path $taskRoot --log-file (Join-Path $taskFolder 'godot.log') --script res://tests/asset_motion_review.gd -- --id=crystal_bat_manual_v3 --model=res://assets/models/rebuilt_enemies/crystal_bat_manual.glb --height=1.1 --category=common_enemy --require-full-fold
    }
    if ($LASTEXITCODE -ne 0) { throw "Bat manual fold review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA, $env:LOCALAPPDATA = $taskPreviousAppData, $taskPreviousLocal
}
