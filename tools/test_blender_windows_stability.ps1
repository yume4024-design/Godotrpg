[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$QaExe,
    [ValidateSet('Short','Soak','Restart')][string]$Mode='Soak',
    [string]$ExistingEvidenceRoot,
    [string]$ReferenceCandidate='D:/RPGGAME/builds/greystone-blender/rc1-63d05f5/candidate/ProjectCrystal.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$QaExe=(Resolve-Path -LiteralPath $QaExe).Path
$ReferenceCandidate=(Resolve-Path -LiteralPath $ReferenceCandidate).Path
$evidenceRoot=Join-Path $projectRoot ('artifacts/blender_windows_stability/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$Mode.ToLower())
New-Item -ItemType Directory -Force $evidenceRoot | Out-Null
$profileRoot=Join-Path $evidenceRoot 'profile'
$localRoot=Join-Path $evidenceRoot 'local'
$tempRoot=Join-Path $evidenceRoot 'temp'
$preservedBefore=@{}
if ($Mode -eq 'Restart') {
    if (-not $ExistingEvidenceRoot) { throw 'Restart needs the completed Soak evidence root.' }
    $previous=Get-Content -LiteralPath (Join-Path $ExistingEvidenceRoot 'manifest.json') -Raw | ConvertFrom-Json
    if ($previous.mode -ne 'Soak' -or -not $previous.passed) { throw 'Restart requires a passed full Soak.' }
    $profileRoot=$previous.profile
    $localRoot=$previous.local
    $tempRoot=$previous.temp
    foreach ($item in @('prologue.json','metrics.json','frames.csv')) {
        $file=@(Get-ChildItem -LiteralPath $profileRoot -Recurse -File -Filter $item)
        if ($file.Count -ne 1) { throw "Missing unique persisted $item" }
        $preservedBefore[$file[0].FullName]=(Get-FileHash -LiteralPath $file[0].FullName).Hash
    }
}
New-Item -ItemType Directory -Force $profileRoot,$localRoot,$tempRoot | Out-Null
$logPath=Join-Path $evidenceRoot 'native.log'
$rssPath=Join-Path $evidenceRoot 'process.csv'
$qaPck=[IO.Path]::ChangeExtension($QaExe,'.pck')
$candidatePck=[IO.Path]::ChangeExtension($ReferenceCandidate,'.pck')
$receiptPath=Join-Path (Split-Path -Parent (Split-Path -Parent $QaExe)) 'build_receipt.json'
$receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
$result=[ordered]@{
    mode=$Mode;qa=$QaExe;candidate=$ReferenceCandidate;profile=$profileRoot;local=$localRoot;temp=$tempRoot
    source_commit=$receipt.source_commit;version='0.6.1-greystone-blender-rc1';log=$logPath;process_samples=$rssPath
    qa_pck_before=(Get-FileHash -LiteralPath $qaPck).Hash
    candidate_pck_before=(Get-FileHash -LiteralPath $candidatePck).Hash
    human_playthrough=$false;physical_input_verified=$false;android_verified=$false;passed=$false
    preserved_before=$preservedBefore;graphical=$true
}
$manifest=Join-Path $evidenceRoot 'manifest.json'
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifest -Encoding utf8
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=$QaExe
$info.Arguments='--log-file "'+$logPath+'"'
if ($Mode -eq 'Short') { $info.Arguments+=' -- --blender-short' }
if ($Mode -eq 'Restart') { $info.Arguments+=' -- --reload --probe-loads' }
$info.WorkingDirectory=Split-Path -Parent $QaExe
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.EnvironmentVariables['APPDATA']=$profileRoot
$info.EnvironmentVariables['LOCALAPPDATA']=$localRoot
$info.EnvironmentVariables['TEMP']=$tempRoot
$info.EnvironmentVariables['TMP']=$tempRoot
$info.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION']='1'
'elapsed_seconds,working_set_bytes,private_bytes,peak_working_set_bytes' | Set-Content -LiteralPath $rssPath
$watch=[Diagnostics.Stopwatch]::StartNew()
$process=$null
try {
    $process=[Diagnostics.Process]::Start($info)
    $result.pid=$process.Id
    $result.started_utc=[DateTime]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifest -Encoding utf8
    Write-Output "BLENDER_STABILITY_EVIDENCE=$evidenceRoot PID=$($process.Id) MODE=$Mode"
    while (-not $process.WaitForExit(1000)) {
        $limit=if ($Mode -eq 'Soak') { 2250 } elseif ($Mode -eq 'Short') { 240 } else { 150 }
        if ($watch.Elapsed.TotalSeconds -gt $limit) { $process.Kill(); throw "Native $Mode exceeded $limit seconds" }
        $process.Refresh()
        if (-not $process.HasExited) {
            ('{0:F3},{1},{2},{3}' -f $watch.Elapsed.TotalSeconds,$process.WorkingSet64,$process.PrivateMemorySize64,$process.PeakWorkingSet64) | Add-Content -LiteralPath $rssPath
        }
    }
    $result.exit_code=$process.ExitCode
    $log=Get-Content -LiteralPath $logPath -Raw
    if ($process.ExitCode -ne 0 -or $log -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw "Native test failed; see $logPath" }
    $reportName=if ($Mode -eq 'Restart') { 'load_probe.json' } else { 'metrics.json' }
    $files=@(Get-ChildItem -LiteralPath $profileRoot -Recurse -File -Filter $reportName | Where-Object {$_.Directory.Name -eq 'g083'})
    if ($files.Count -ne 1) { throw "Missing unique $reportName" }
    $result.metrics=$files[0].FullName
    $metrics=Get-Content -LiteralPath $result.metrics -Raw | ConvertFrom-Json
    if (-not $metrics.release -or $metrics.display -eq 'headless' -or $metrics.failures -ne 0) { throw 'Native graphical release acceptance failed.' }
    if ($Mode -ne 'Restart') {
        $target=if ($Mode -eq 'Soak') { 1800 } else { 70 }
        if (-not $metrics.complete -or $metrics.soak_seconds -lt $target -or $metrics.target_seconds -ne $target) { throw 'Native duration gate failed.' }
        if ($Mode -eq 'Soak' -and $metrics.short_preflight) { throw 'Short preflight cannot count as full Soak.' }
    }
    $preservedAfter=@{}
    foreach ($path in $preservedBefore.Keys) {
        $preservedAfter[$path]=(Get-FileHash -LiteralPath $path).Hash
        if ($preservedAfter[$path] -ne $preservedBefore[$path]) { throw "Restart modified original evidence/save: $path" }
    }
    $result.preserved_after=$preservedAfter
    $result.qa_pck_after=(Get-FileHash -LiteralPath $qaPck).Hash
    $result.candidate_pck_after=(Get-FileHash -LiteralPath $candidatePck).Hash
    if ($result.qa_pck_before -ne $result.qa_pck_after -or $result.candidate_pck_before -ne $result.candidate_pck_after) { throw 'Test package changed during verification.' }
    $result.passed=$true
    $log -split "`r?`n" | Where-Object {$_ -match 'G083_RESULT|G083_SOAK_STARTED'} | Write-Output
} catch {
    $result.error=$_.Exception.Message
    throw
} finally {
    $result.seconds=$watch.Elapsed.TotalSeconds
    $result.ended_utc=[DateTime]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifest -Encoding utf8
    if ($null -ne $process) { $process.Dispose() }
    Write-Output "BLENDER_STABILITY_MANIFEST=$manifest"
}
