[CmdletBinding()]
param([switch]$Test)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$taskOutput = Join-Path $taskRoot 'artifacts/asset_a05/item_merchant'
$taskProfile = Join-Path $taskOutput 'profile'
$taskLocal = Join-Path $taskOutput 'local'
New-Item -ItemType Directory -Force $taskProfile, $taskLocal | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = $taskProfile
    $env:LOCALAPPDATA = $taskLocal
    $taskArguments = @('--path', $taskRoot, '--log-file', (Join-Path $taskOutput 'godot_static.log'), 'res://scenes/tools/npc_static_preview.tscn')
    if ($Test) {$taskArguments += @('--', '--npc-static-test')}
    & $taskEngine @taskArguments
    if ($LASTEXITCODE -ne 0) {throw "NPC preview failed ($LASTEXITCODE)"}
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
