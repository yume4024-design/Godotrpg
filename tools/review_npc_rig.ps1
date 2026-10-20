[CmdletBinding()]
param([ValidateSet('blacksmith','item_merchant','villager_male','villager_female','innkeeper')][string]$Asset = 'blacksmith', [switch]$Controller)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$taskOutput = Join-Path $taskRoot ('artifacts/asset_a05/' + $Asset)
$taskProfile = Join-Path $taskOutput 'profile'
$taskLocal = Join-Path $taskOutput 'local'
New-Item -ItemType Directory -Force $taskProfile, $taskLocal | Out-Null
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = $taskProfile
    $env:LOCALAPPDATA = $taskLocal
    $taskArguments = @('--path', $taskRoot, '--log-file', (Join-Path $taskOutput $(if ($Controller) {'controller.log'} else {'rig.log'})))
    if ($Controller) {$taskArguments += @('--script', 'res://tests/npc_visual_test.gd', '--', ('--id=' + $Asset))}
    else {
        $taskHeight = switch ($Asset) {'blacksmith' {'1.85'} 'item_merchant' {'1.65'} 'villager_male' {'1.75'} 'villager_female' {'1.65'} 'innkeeper' {'1.72'}}
        $taskArguments += @('--script', 'res://tests/asset_motion_review.gd', '--', ('--id=' + $Asset), '--category=npc', ('--height=' + $taskHeight), ('--model=res://assets/models/rebuilt_npc/' + $Asset + '.glb'))
    }
    & $taskEngine @taskArguments
    if ($LASTEXITCODE -ne 0) {throw "NPC rig review failed ($LASTEXITCODE)"}
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocal
}
