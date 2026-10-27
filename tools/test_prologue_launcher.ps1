[CmdletBinding()]
param(
    [ValidateRange(65, 300)]
    [int]$ObserveSeconds = 70
)

# Exercise the public launcher in a separate shell, including its lifetime.
# This does not play the prologue or replace controller/art acceptance.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $projectRoot ('artifacts/launcher/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$launcher = Join-Path $PSScriptRoot 'godot.ps1'
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = (Get-Process -Id $PID).Path
$startInfo.Arguments = '-NoProfile -File "{0}" -Mode RunPrologueCandidate' -f $launcher
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION'] = '1'
$shellProcess = New-Object System.Diagnostics.Process
$shellProcess.StartInfo = $startInfo
$gameProcess = $null
$samples = [Collections.Generic.List[object]]::new()
$result = [ordered]@{ status = 'FAIL'; observation_seconds = $ObserveSeconds; headless = $false }
$clock = [Diagnostics.Stopwatch]::StartNew()
try {
    if (-not $shellProcess.Start()) { throw 'Launcher shell did not start.' }
    $stdoutTask = $shellProcess.StandardOutput.ReadLineAsync()
    $stderrTask = $shellProcess.StandardError.ReadToEndAsync()
    if (-not $shellProcess.WaitForExit(75000)) {
        $shellProcess.Kill()
        throw 'Launcher shell did not return within 75 seconds.'
    }
    $result.launcher_seconds = $clock.Elapsed.TotalSeconds
    if (-not $stdoutTask.Wait(5000) -or -not $stderrTask.Wait(5000)) {
        throw 'A detached child kept launcher output pipes open.'
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $stdout | Set-Content (Join-Path $evidence 'stdout.txt') -Encoding UTF8
    $stderr | Set-Content (Join-Path $evidence 'stderr.txt') -Encoding UTF8
    if ($shellProcess.ExitCode -ne 0) { throw "Launcher exited $($shellProcess.ExitCode): $stderr" }
    if ($stdout -notmatch 'Started RunPrologueCandidate \(PID (\d+)\)\. Log: (.+)') {
        throw 'Launcher did not report a detached game process.'
    }
    $gameProcess = Get-Process -Id ([int]$Matches[1])
    $logPath = $Matches[2].Trim()
    $result.game_pid = $gameProcess.Id
    $result.log_path = $logPath
    $remainingOutput = $shellProcess.StandardOutput.ReadToEndAsync()
    if (-not $remainingOutput.Wait(5000)) { throw 'Detached game kept launcher stdout open.' }
    if ($result.launcher_seconds -gt 15) { throw 'Launcher took more than 15 seconds to detach.' }
    $gameClock = [Diagnostics.Stopwatch]::StartNew()
    do {
        $gameProcess.Refresh()
        if ($gameProcess.HasExited) { throw 'Game exited during the observation period.' }
        $samples.Add([ordered]@{
            elapsed_seconds = $gameClock.Elapsed.TotalSeconds
            window_present = ($gameProcess.MainWindowHandle -ne [IntPtr]::Zero)
            responding = $gameProcess.Responding
            working_set_bytes = $gameProcess.WorkingSet64
        })
        Start-Sleep -Milliseconds 2000
    } while ($gameClock.Elapsed.TotalSeconds -lt $ObserveSeconds)
    $gameProcess.Refresh()
    if ($gameProcess.HasExited) { throw 'Game exited at the observation boundary.' }
    if (-not $samples[-1].window_present -or -not $samples[-1].responding) {
        throw 'Graphical game window was missing or unresponsive.'
    }
    if (-not (Test-Path -LiteralPath $logPath)) { throw 'Godot log is missing.' }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -notmatch 'OpenGL|Vulkan|Direct3D') { throw 'No graphical renderer recorded.' }
    if ($log -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
        throw 'Godot reported an error; inspect the captured log.'
    }
    $result.observed_seconds = $gameClock.Elapsed.TotalSeconds
    $result.status = 'PASS'
} catch {
    $result.error = $_.Exception.Message
} finally {
    # Only close the process returned by this invocation, never other game windows.
    if ($null -ne $gameProcess) {
        $gameProcess.Refresh()
        if (-not $gameProcess.HasExited) {
            [void]$gameProcess.CloseMainWindow()
            if (-not $gameProcess.WaitForExit(5000)) { $gameProcess.Kill() }
        }
        $gameProcess.Dispose()
    }
    $shellProcess.Dispose()
    $result.samples = $samples.ToArray()
    $result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $evidence 'result.json') -Encoding UTF8
}
Write-Output "$($result.status): $evidence"
if ($result.status -ne 'PASS') { throw $result.error }
