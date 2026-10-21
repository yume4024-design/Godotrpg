[CmdletBinding()]
param([ValidateSet('ren','lia')][string]$Character = 'ren')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOut = Join-Path $taskRoot ('artifacts/character_rebuild_20261020/' + $Character + '/godot_static')
New-Item -ItemType Directory -Force "$taskOut/profile", "$taskOut/local" | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = "$taskOut/profile"
    $env:LOCALAPPDATA = "$taskOut/local"
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path $taskRoot --log-file "$taskOut/godot.log" --script res://tests/static_character_review.gd -- "--id=$Character" "--model=res://assets/models/rebuilt_characters/${Character}_static.glb"
    if ($LASTEXITCODE -ne 0) { throw "Static character review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
