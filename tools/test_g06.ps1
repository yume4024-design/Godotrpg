[CmdletBinding()]
param([switch]$IsolateJoypadMotion)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$reportFolder = Join-Path $projectRoot 'artifacts/regression'
New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
$reportFile = Join-Path $reportFolder ('g06-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$modes = @('Check','TestEnemyAI','TestPhase3','Smoke','TestPhase5','TestPhase5Reload','TestPhase6','TestG06','TestG06Reload','TestG06NPC','TestG06Story','TestG06StoryReload','VisualG06Story','VisualG06Touch','VisualG06TouchCommerce','TestG06CommerceReload')
$results = [System.Collections.Generic.List[object]]::new()
$head = git -C $projectRoot rev-parse HEAD
$dirty = [bool](git -C $projectRoot status --porcelain)
$taskPriorInputIsolation = $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION
try {
foreach ($mode in $modes) {
    # Only the scripted native story walk needs this isolation. Phase6 and touch
    # modes intentionally inject joypad events and must retain their bindings.
    $taskIsolatedMode = $IsolateJoypadMotion -and $mode -eq 'VisualG06Story'
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = if ($taskIsolatedMode) {'1'} else {$taskPriorInputIsolation}
    $started = Get-Date
    $passed = $false
    $resultLines = @()
    $failure = ''
    try {
        $output = & (Join-Path $PSScriptRoot 'godot.ps1') -Mode $mode
        $resultLines = @(($output -split "`r?`n") | Where-Object { $_ -match '^[A-Z0-9_]+_RESULT|^Log:' })
        $passed = $true
    } catch {
        $failure = $_.Exception.Message
    }
    $logs = Get-ChildItem (Join-Path $projectRoot 'artifacts/logs') -Filter ($mode.ToLowerInvariant()+'-*.log') | Sort-Object LastWriteTime -Descending
    $log = if ($logs.Count -gt 0) { $logs[0].Name } else { '' }
    $results.Add([pscustomobject]@{mode=$mode;passed=$passed;phase5_joypad_motion_isolated=[bool]$taskIsolatedMode;started=$started.ToString('o');seconds=[math]::Round(((Get-Date)-$started).TotalSeconds,2);log=$log;result=$resultLines;error=$failure})
    [pscustomobject]@{base_commit=$head;dirty_worktree=$dirty;platform='Windows desktop; touch and controller events simulated';joypad_motion_isolation_requested=[bool]$IsolateJoypadMotion;android_verified=$false;results=$results.ToArray()} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportFile -Encoding utf8
    Write-Output "$mode passed=$passed log=$log"
    $resultLines | Write-Output
    if (-not $passed) { throw "$mode failed: $failure. Manifest: $reportFile" }
}
Write-Output "G06 regression complete. Manifest: $reportFile"
} finally {
    $env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = $taskPriorInputIsolation
}
