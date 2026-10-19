[CmdletBinding()]
param(
    [ValidateSet('spore_sprite','ore_beetle','thorn_boar','crystal_bat','corrupted_guardian')]
    [string]$Asset = 'spore_sprite'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$taskOutput = Join-Path $taskRoot ('artifacts/asset_a03/' + $Asset)
$taskProfile = Join-Path $taskOutput 'profile'
$taskLocal = Join-Path $taskOutput 'local'
New-Item -ItemType Directory -Force $taskProfile, $taskLocal | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
$taskHeight = @{spore_sprite='1.2'; ore_beetle='0.9'; thorn_boar='1.3'; crystal_bat='1.1'; corrupted_guardian='2.4'}[$Asset]
$taskCategory = if ($Asset -eq 'corrupted_guardian') {'boss'} else {'common_enemy'}
try {
    $env:APPDATA = $taskProfile
    $env:LOCALAPPDATA = $taskLocal
    & $taskEngine --path $taskRoot --log-file (Join-Path $taskOutput 'godot.log') --script res://tests/asset_motion_review.gd -- "--id=$Asset" "--model=res://assets/models/rebuilt_enemies/$Asset.glb" "--height=$taskHeight" "--category=$taskCategory"
    if ($LASTEXITCODE -ne 0) {throw "Asset review failed: $Asset ($LASTEXITCODE)"}
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
