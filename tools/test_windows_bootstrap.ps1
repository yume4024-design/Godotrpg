[CmdletBinding()]
param([switch]$Reload)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$taskOut=Join-Path $taskRoot 'artifacts/windows_bootstrap'
New-Item -ItemType Directory -Force "$taskOut/profile","$taskOut/local" | Out-Null
$taskPriorApp=$env:APPDATA
$taskPriorLocal=$env:LOCALAPPDATA
try {
 $env:APPDATA="$taskOut/profile"
 $env:LOCALAPPDATA="$taskOut/local"
 $taskArgs=@('--path',$taskRoot,'--log-file',"$taskOut/$(if($Reload){'reload'}else{'story'}).log",'--script','res://tests/windows_bootstrap_story_test.gd')
 if($Reload){$taskArgs+=@('--','--reload')}
 & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' @taskArgs
 if($LASTEXITCODE-ne 0){throw 'Loading-screen story regression failed; preserve the first failure.'}
}finally{
 $env:APPDATA=$taskPriorApp
 $env:LOCALAPPDATA=$taskPriorLocal
}
