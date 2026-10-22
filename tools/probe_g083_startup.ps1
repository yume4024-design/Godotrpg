[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProbeExe,
    [int]$Repeats = 3,
    [switch]$LoadingScreen,
    [ValidateSet('production','60')][string]$FramePolicy = 'production'
)
$ErrorActionPreference = 'Stop'
if ($Repeats -lt 1 -or $Repeats -gt 5) { throw 'Use 1 to 5 measured repeats, not an unbounded loop.' }
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskExe = (Resolve-Path -LiteralPath $ProbeExe).Path
$taskPck = [IO.Path]::ChangeExtension($taskExe, '.pck')
$taskExpected = (Get-FileHash -LiteralPath $taskPck).Hash
$taskComparison = Join-Path (Split-Path -Parent $taskExe) 'comparison.json'
if (-not (Test-Path -LiteralPath $taskComparison)) { throw 'Compare every shared game entry against fixed RC3 before measuring this QA build.' }
$taskEquivalence = Get-Content -LiteralPath $taskComparison -Raw | ConvertFrom-Json
if ($taskEquivalence.status -ne 'PASS' -or $taskEquivalence.probe_pck_sha256 -ne $taskExpected.ToLowerInvariant()) { throw 'QA comparison is missing, failed or belongs to a different PCK.' }
$taskEvidence = Join-Path $taskRoot ('artifacts/g083_startup_20261022/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskProbe = Join-Path $taskRoot 'tests/g083_startup_probe.gd'
$taskRows = [Collections.Generic.List[object]]::new()
foreach ($taskCache in @('app_cache_fresh', 'same_app_cache_repeat', 'shader_cache_only_copy')) {
    for ($taskRepeat = 0; $taskRepeat -lt $Repeats; $taskRepeat++) {
        $taskRun = Join-Path $taskEvidence ($taskCache + '-' + $taskRepeat)
        # Each fresh run has a new app folder. Its paired repeat uses the same
        # folder and shader cache; no system/driver cache is purged or claimed.
        $taskProfile = Join-Path $taskEvidence ('cache-' + $taskRepeat)
        if ($taskCache -eq 'shader_cache_only_copy') { $taskProfile = Join-Path $taskEvidence ('transplant-' + $taskRepeat) }
        New-Item -ItemType Directory -Force $taskRun, "$taskProfile/profile", "$taskProfile/local", "$taskProfile/temp" | Out-Null
        if ($taskCache -eq 'shader_cache_only_copy') {
            $taskOriginalProfile = Join-Path $taskEvidence ('cache-' + $taskRepeat + '/profile')
            $taskShader = @(Get-ChildItem -LiteralPath $taskOriginalProfile -Directory -Recurse -Filter 'shader_cache')
            if ($taskShader.Count -ne 1) { throw 'Expected exactly one owned Godot shader cache to transplant.' }
            $taskRelative = [IO.Path]::GetRelativePath($taskOriginalProfile, $taskShader[0].FullName)
            $taskDestination = Join-Path "$taskProfile/profile" $taskRelative
            New-Item -ItemType Directory -Force (Split-Path -Parent $taskDestination) | Out-Null
            Copy-Item -LiteralPath $taskShader[0].FullName -Destination $taskDestination -Recurse
        }
        $taskInfo = [Diagnostics.ProcessStartInfo]::new()
        $taskInfo.FileName = $taskExe
        $taskInfo.WorkingDirectory = Split-Path -Parent $taskExe
        $taskInfo.Arguments = '--log-file "' + (Join-Path $taskRun 'engine.log') + '" -- --probe-output="' + $taskRun + '"'
        if ($LoadingScreen) { $taskInfo.Arguments += ' --loading-screen' }
        if ($FramePolicy -eq '60') { $taskInfo.Arguments += ' --frame-cap=60' }
        $taskInfo.UseShellExecute = $false
        $taskInfo.CreateNoWindow = $true
        $taskInfo.RedirectStandardOutput = $true
        $taskInfo.RedirectStandardError = $true
        $taskInfo.EnvironmentVariables['APPDATA'] = "$taskProfile/profile"
        $taskInfo.EnvironmentVariables['LOCALAPPDATA'] = "$taskProfile/local"
        $taskInfo.EnvironmentVariables['TEMP'] = "$taskProfile/temp"
        $taskInfo.EnvironmentVariables['TMP'] = "$taskProfile/temp"
        $taskWatch = [Diagnostics.Stopwatch]::StartNew()
        $taskProcess = [Diagnostics.Process]::Start($taskInfo)
        $taskStdout = $taskProcess.StandardOutput.ReadToEndAsync()
        $taskStderr = $taskProcess.StandardError.ReadToEndAsync()
        $taskSamples = [Collections.Generic.List[object]]::new()
        $taskTimedOut = $false
        try {
            while (-not $taskProcess.WaitForExit(100)) {
                if ($taskWatch.Elapsed.TotalSeconds -gt 45) { $taskTimedOut = $true; $taskProcess.Kill(); $taskProcess.WaitForExit(); break }
                $taskProcess.Refresh()
                if (-not $taskProcess.HasExited) {
                    $taskSamples.Add([pscustomobject]@{seconds=$taskWatch.Elapsed.TotalSeconds;working_set_bytes=$taskProcess.WorkingSet64;private_bytes=$taskProcess.PrivateMemorySize64;peak_working_set_bytes=$taskProcess.PeakWorkingSet64;cpu_seconds=$taskProcess.TotalProcessorTime.TotalSeconds})
                }
            }
            $taskStdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $taskRun 'stdout.txt') -Encoding utf8
            $taskStderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $taskRun 'stderr.txt') -Encoding utf8
            $taskRows.Add([pscustomobject]@{cache=$taskCache;repeat=$taskRepeat;pid=$taskProcess.Id;exit_code=$taskProcess.ExitCode;seconds=$taskWatch.Elapsed.TotalSeconds;directory=$taskRun;timed_out=$taskTimedOut;loading_screen=[bool]$LoadingScreen})
            $taskSamples | Export-Csv -LiteralPath (Join-Path $taskRun 'process.csv') -NoTypeInformation -Encoding utf8
            $taskRows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskEvidence 'runs.json') -Encoding utf8
            if ($taskTimedOut) { throw 'Only this startup probe exceeded 45 seconds; stdout/stderr and process samples have been preserved.' }
            if ($taskProcess.ExitCode -ne 0) { throw "Native startup probe failed: $taskRun" }
            $taskMetrics = Get-Content -LiteralPath (Join-Path $taskRun 'startup.json') -Raw | ConvertFrom-Json
            if (-not $taskMetrics.release -or -not $taskMetrics.feature -or $taskMetrics.display -eq 'headless' -or $taskMetrics.errors.Count -ne 0) { throw "Startup gates failed: $taskRun" }
            Write-Output "G083_STARTUP_RUN cache=$taskCache repeat=$taskRepeat frames=$($taskMetrics.frames.Count) output=$taskRun"
        } finally { $taskProcess.Dispose() }
    }
}
$taskHashes = [ordered]@{pck_before=$taskExpected;pck_after=(Get-FileHash -LiteralPath $taskPck).Hash;exe_sha256=(Get-FileHash -LiteralPath $taskExe).Hash;probe_sha256=(Get-FileHash -LiteralPath $taskProbe).Hash;source_commit=(git -C $taskRoot rev-parse HEAD);cold_driver_cache_claimed=$false;gameplay_methods_replaced=$false}
$taskHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskEvidence 'sources.json') -Encoding utf8
if ($taskHashes.pck_after -ne $taskExpected) { throw 'Candidate PCK changed during the observation.' }
Write-Output "G083_STARTUP_EVIDENCE=$taskEvidence"
