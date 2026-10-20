[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $taskRoot 'artifacts/free_environment_20261020/fallen_log'
New-Item -ItemType Directory -Force "$taskOutput/profile", "$taskOutput/local" | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = "$taskOutput/profile"
    $env:LOCALAPPDATA = "$taskOutput/local"
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path $taskRoot --log-file "$taskOutput/godot.log" --script res://tests/forest_log_test.gd
    if ($LASTEXITCODE -ne 0) { throw "Forest log review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
