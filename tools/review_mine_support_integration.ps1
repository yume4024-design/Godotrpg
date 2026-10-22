[CmdletBinding()]
param([switch]$RecordBaseline,[string]$Fixture = '')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOut = Join-Path $taskRoot 'artifacts/env02_mine_integration'
$taskFixture = $Fixture
if ([string]::IsNullOrWhiteSpace($taskFixture)) {
    $taskFixture = Join-Path $taskRoot 'artifacts/g083/20261022-121807/profile/Godot/app_userdata/失落星核 — Project Crystal/g08_tests/prologue.json'
    if (-not (Test-Path -LiteralPath $taskFixture)) {
        $taskFixture = Join-Path $taskRoot 'artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/g06_story_tests/restart.json'
    }
}
if (-not (Test-Path -LiteralPath $taskFixture)) { throw 'Run tools/godot.ps1 -Mode TestG06Story first, or supply -Fixture with a real completed QA save. Do not invent a passed save.' }
$taskUser = Join-Path $taskOut 'profile/Godot/app_userdata/失落星核 — Project Crystal/env02_mine'
New-Item -ItemType Directory -Force $taskUser,"$taskOut/local","$taskRoot/source_assets/environment_rebuild_20261022/mine_support_integration" | Out-Null
Copy-Item -LiteralPath $taskFixture -Destination "$taskUser/session.json"
$taskPriorApp = $env:APPDATA
$taskPriorLocal = $env:LOCALAPPDATA
$taskOverride = Join-Path $taskRoot 'override.cfg'
$taskOverrideText = "[display]`nwindow/size/no_focus=true`n"
$taskOwnsOverride = $false
try {
    if (Test-Path -LiteralPath $taskOverride) { throw 'Preserve existing override.cfg; native test did not start.' }
    [IO.File]::WriteAllText($taskOverride,$taskOverrideText,[Text.UTF8Encoding]::new($false))
    $taskOwnsOverride = $true
    $env:APPDATA = "$taskOut/profile"
    $env:LOCALAPPDATA = "$taskOut/local"
    $taskName = if ($RecordBaseline) {'before'} else {'after'}
    $taskArgs = @('--path',$taskRoot,'--log-file',"$taskOut/$taskName.log",'--script','res://tests/mine_support_integration_test.gd')
    if ($RecordBaseline) { $taskArgs += @('--','--record-baseline') }
    $taskStarted = [DateTime]::UtcNow
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' @taskArgs
    if ($LASTEXITCODE -ne 0) { throw 'Mine integration native test failed; preserve its log.' }
    $taskReport = Get-Item -LiteralPath "$taskOut/$(if ($RecordBaseline) {'before_result'} else {'result'}).json"
    $taskResult = Get-Content -LiteralPath $taskReport.FullName -Raw | ConvertFrom-Json
    if ($taskReport.LastWriteTimeUtc -lt $taskStarted -or $taskResult.failures -ne 0 -or $taskResult.baseline -ne [bool]$RecordBaseline) { throw 'Missing fresh result or wrong mode.' }
    $taskLog = Get-Content -LiteralPath "$taskOut/$taskName.log" -Raw
    if ($taskLog -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw 'Engine error despite exit status; preserve failed evidence.' }
} finally {
    $env:APPDATA = $taskPriorApp
    $env:LOCALAPPDATA = $taskPriorLocal
    if ($taskOwnsOverride) {
        if ([IO.File]::ReadAllText($taskOverride) -ne $taskOverrideText) { throw 'Concurrent override edit preserved.' }
        Remove-Item -LiteralPath $taskOverride
    }
}
