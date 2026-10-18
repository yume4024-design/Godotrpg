[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$QaExe, [ValidateSet('Soak','Probe')][string]$Mode = 'Soak')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$QaExe = (Resolve-Path -LiteralPath $QaExe).Path
$evidenceRoot = Join-Path $projectRoot ('artifacts/g083/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$profileRoot = Join-Path $evidenceRoot 'profile'
$localRoot = Join-Path $evidenceRoot 'local'
$tempRoot = Join-Path $evidenceRoot 'temp'
New-Item -ItemType Directory -Force $profileRoot,$localRoot,$tempRoot | Out-Null
$logPath = Join-Path $evidenceRoot 'release-soak.log'
$rssPath = Join-Path $evidenceRoot 'process.csv'
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $QaExe
$info.Arguments = '--log-file "' + $logPath + '"'
if ($Mode -eq 'Probe') { $info.Arguments += ' -- --probe-loads' }
$info.WorkingDirectory = Split-Path -Parent $QaExe
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.EnvironmentVariables['APPDATA'] = $profileRoot
$info.EnvironmentVariables['LOCALAPPDATA'] = $localRoot
$info.EnvironmentVariables['TEMP'] = $tempRoot
$info.EnvironmentVariables['TMP'] = $tempRoot
'elapsed_seconds,working_set_bytes,private_bytes,peak_working_set_bytes' | Set-Content $rssPath
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = [Diagnostics.Process]::Start($info)
Write-Output "G083_EVIDENCE=$evidenceRoot PID=$($process.Id)"
try {
    while (-not $process.WaitForExit(1000)) {
        $limit = if ($Mode -eq 'Probe') { 120 } else { 1950 }
        if ($watch.Elapsed.TotalSeconds -gt $limit) { $process.Kill(); throw "Release $Mode exceeded $limit seconds" }
        $process.Refresh()
        if (-not $process.HasExited) {
            ('{0:F3},{1},{2},{3}' -f $watch.Elapsed.TotalSeconds,$process.WorkingSet64,$process.PrivateMemorySize64,$process.PeakWorkingSet64) | Add-Content $rssPath
        }
    }
    $log = Get-Content $logPath -Raw
    $result = [ordered]@{mode=$Mode;base_commit=(git -C $projectRoot rev-parse HEAD);exe=$QaExe;pck_sha256=(Get-FileHash ([IO.Path]::ChangeExtension($QaExe,'.pck'))).Hash;pid=$process.Id;seconds=$watch.Elapsed.TotalSeconds;exit_code=$process.ExitCode;log=$logPath;process_samples=$rssPath;human_playthrough=$false;android_verified=$false}
    $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $evidenceRoot 'manifest.json') -Encoding utf8
    $reportName = if ($Mode -eq 'Probe') { 'load_probe.json' } else { 'metrics.json' }
    $metricsFile = @(Get-ChildItem $profileRoot -Recurse -Filter $reportName | Where-Object {$_.Directory.Name -eq 'g083'})
    if ($metricsFile.Count -ne 1) { throw 'Missing unique native release metrics' }
    $metrics = Get-Content $metricsFile[0].FullName -Raw | ConvertFrom-Json
    $result.metrics = $metricsFile[0].FullName
    $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $evidenceRoot 'manifest.json') -Encoding utf8
    if ($process.ExitCode -ne 0 -or $log -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw "Release soak failed: $logPath" }
    if (-not $metrics.release -or $metrics.display -eq 'headless' -or $metrics.failures -ne 0) { throw 'Release acceptance gates failed' }
    if ($Mode -eq 'Soak' -and (-not $metrics.complete -or $metrics.soak_seconds -lt 1800)) { throw 'Release soak did not reach 30 minutes' }
    $log -split "`r?`n" | Where-Object {$_ -match 'G083_RESULT|G083_SOAK_STARTED'} | Write-Output
    Write-Output "G083_MANIFEST=$(Join-Path $evidenceRoot 'manifest.json')"
} finally { $process.Dispose() }
