[CmdletBinding()]
param([switch]$RecordBaseline)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskOut=Join-Path $taskRoot 'artifacts/env02_village_integration'
New-Item -ItemType Directory -Force "$taskOut/profile", "$taskOut/local" | Out-Null
$taskPreviousAppData=$env:APPDATA
$taskPreviousLocal=$env:LOCALAPPDATA
try {
    $env:APPDATA="$taskOut/profile"
    $env:LOCALAPPDATA="$taskOut/local"
    $taskArgs=@('--path',$taskRoot,'--log-file',"$taskOut/$(if($RecordBaseline){'baseline'}else{'review'}).log",'--script','res://tests/greystone_environment_integration_test.gd')
    if ($RecordBaseline) { $taskArgs += @('--','--record-baseline') }
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' @taskArgs
    if ($LASTEXITCODE -ne 0) { throw "Village ENV02 review failed ($LASTEXITCODE)" }
} finally {
    $env:APPDATA=$taskPreviousAppData
    $env:LOCALAPPDATA=$taskPreviousLocal
}
