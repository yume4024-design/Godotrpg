[CmdletBinding()]
param([switch]$Visual)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOut = Join-Path $taskRoot 'artifacts/env02_mine_support'
New-Item -ItemType Directory -Force "$taskOut/profile","$taskOut/local" | Out-Null
$taskPriorApp = $env:APPDATA
$taskPriorLocal = $env:LOCALAPPDATA
$taskOverride = Join-Path $taskRoot 'override.cfg'
$taskOverrideText = "[display]`nwindow/size/no_focus=true`n"
$taskOwnsOverride = $false
try {
    if ($Visual) {
        if (Test-Path -LiteralPath $taskOverride) { throw 'Preserve the existing user override.cfg; native review did not start.' }
        [IO.File]::WriteAllText($taskOverride,$taskOverrideText,[Text.UTF8Encoding]::new($false))
        $taskOwnsOverride = $true
    }
    $env:APPDATA = "$taskOut/profile"
    $env:LOCALAPPDATA = "$taskOut/local"
    $taskArgs = @('--path',$taskRoot,'--log-file',"$taskOut/$(if($Visual){'visual'}else{'structural'}).log",'--script','res://tests/mine_support_test.gd')
    if (-not $Visual) { $taskArgs = @('--headless') + $taskArgs }
    $taskStarted = [DateTime]::UtcNow
    & 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' @taskArgs
    if ($LASTEXITCODE -ne 0) { throw 'Mine support review failed; preserve its log.' }
    $taskReport = Get-Item -LiteralPath "$taskOut/$(if($Visual){'graphical'}else{'structural'}).json"
    $taskResult = Get-Content -LiteralPath $taskReport.FullName -Raw | ConvertFrom-Json
    if ($taskReport.LastWriteTimeUtc -lt $taskStarted -or $taskResult.failures.Count -ne 0 -or $taskResult.graphical -ne [bool]$Visual) {
        throw 'Missing fresh result or failed mode gate; an early exit is not acceptance.'
    }
    if ($Visual -and $taskResult.captures.Count -ne 4) { throw 'Missing native viewport captures.' }
    $taskLog = Get-Content -LiteralPath "$taskOut/$(if($Visual){'visual'}else{'structural'}).log" -Raw
    if ($taskLog -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
        throw 'Engine error despite exit status; preserve the failed log.'
    }
} finally {
    $env:APPDATA = $taskPriorApp
    $env:LOCALAPPDATA = $taskPriorLocal
    if ($taskOwnsOverride) {
        if ([IO.File]::ReadAllText($taskOverride) -ne $taskOverrideText) { throw 'Concurrent override edit preserved; remove only the owned no-focus settings manually.' }
        Remove-Item -LiteralPath $taskOverride
    }
}
