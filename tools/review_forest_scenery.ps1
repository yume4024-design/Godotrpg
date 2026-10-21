[CmdletBinding()]
param([switch]$RecordBaseline)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $taskRoot 'artifacts/env02_forest_integration'
$taskFixture = Join-Path $taskRoot 'artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/p5_tests/restart.json'
if (-not (Test-Path -LiteralPath $taskFixture)) { throw 'Run tools/godot.ps1 -Mode TestG06Story to prepare the real completed fixture first.' }
$taskUser = Join-Path $taskOutput 'profile/Godot/app_userdata/失落星核 — Project Crystal/p5_tests'
New-Item -ItemType Directory -Force $taskUser, "$taskOutput/local", "$taskRoot/source_assets/environment_rebuild_20261020/forest_integration" | Out-Null
Copy-Item -LiteralPath $taskFixture -Destination "$taskUser/restart.json"
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = "$taskOutput/profile"
    $env:LOCALAPPDATA = "$taskOutput/local"
    $taskArguments = @('--path', $taskRoot, '--log-file', "$taskOutput/$(if ($RecordBaseline) {'before'} else {'after'}).log", '--script', 'res://tests/forest_scenery_integration_test.gd')
    if ($RecordBaseline) { $taskArguments += @('--','--record-baseline') }
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' @taskArguments
    if ($LASTEXITCODE -ne 0) { throw "Forest scenery review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
