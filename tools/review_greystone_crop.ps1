[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOut = Join-Path $taskRoot 'artifacts/environment_rebuild_20261020/leafy_crop'
New-Item -ItemType Directory -Force "$taskOut/profile", "$taskOut/local" | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = "$taskOut/profile"
    $env:LOCALAPPDATA = "$taskOut/local"
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path $taskRoot --log-file "$taskOut/godot.log" --script res://tests/greystone_crop_test.gd
    if ($LASTEXITCODE -ne 0) { throw "Crop review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
