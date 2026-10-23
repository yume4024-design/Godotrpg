[CmdletBinding()]
param([string]$Launcher = '', [string]$ReadyMarker = '', [ValidateRange(8,90)][int]$ObservationSeconds = 8)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Launcher) { $Launcher = Join-Path $projectRoot 'builds/g08/rc3-20261020/candidate/start_rc3.cmd' }
$Launcher = (Resolve-Path -LiteralPath $Launcher).Path
$folder = Split-Path -Parent $Launcher
$output = Join-Path $projectRoot ('artifacts/rc3-launcher-fix/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $output | Out-Null
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $env:ComSpec
$info.Arguments = '/d /c ""' + $Launcher + '""'
$info.WorkingDirectory = $folder
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.EnvironmentVariables['RC3_NO_PAUSE'] = '1'
$clock = [Diagnostics.Stopwatch]::StartNew()
$launcherProcess = [Diagnostics.Process]::Start($info)
$stdout = $launcherProcess.StandardOutput.ReadToEndAsync()
$stderr = $launcherProcess.StandardError.ReadToEndAsync()
$game = $null
$receipt = [ordered]@{launcher=$Launcher;launcher_pid=$launcherProcess.Id;mode='Normal graphical launch without --preview-smoke; observe owned child then request normal window close';physical_input=$false;passed=$false}
try {
    while ($clock.Elapsed.TotalSeconds -lt 15) {
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($launcherProcess.Id) AND Name='ProjectCrystal.exe'")
        if ($children.Count -eq 1) {
            $game = [Diagnostics.Process]::GetProcessById($children[0].ProcessId)
            $null = $game.Handle # Retain a native handle so exit status survives process removal.
            if ($children[0].CommandLine -notmatch '--log-file "([^"]+)"') { throw 'Owned game did not receive its isolated log argument' }
            $receipt.log = $Matches[1]
            break
        }
        if ($launcherProcess.HasExited) { throw 'Launcher exited before creating the game process' }
        Start-Sleep -Milliseconds 200
    }
    if ($null -eq $game) { throw 'Missing uniquely owned game child' }
    $receipt.game_pid = $game.Id
    while ($clock.Elapsed.TotalSeconds -lt $ObservationSeconds) {
        if ($game.HasExited) { throw 'Game exited unexpectedly during ordinary startup' }
        Start-Sleep -Milliseconds 200
    }
    $game.Refresh()
    $receipt.window_handle = $game.MainWindowHandle.ToInt64()
    $receipt.window_title = $game.MainWindowTitle
    $receipt.responding = $game.Responding
    $receipt.observed_seconds = $clock.Elapsed.TotalSeconds
    if ($game.HasExited -or $receipt.window_handle -eq 0 -or -not $receipt.responding) { throw 'Ordinary game window was not live and responsive' }
    if (-not $game.CloseMainWindow()) { throw 'Owned test window refused normal close request' }
    if (-not $game.WaitForExit(10000)) { throw 'Owned game did not exit normally after window close' }
    if (-not $launcherProcess.WaitForExit(10000)) { throw 'Launcher failed to propagate ordinary close' }
    $receipt.game_exit_code = $game.ExitCode
    $receipt.launcher_exit_code = $launcherProcess.ExitCode
    $receipt.stdout = $stdout.GetAwaiter().GetResult()
    $receipt.stderr = $stderr.GetAwaiter().GetResult()
    if ($game.ExitCode -ne 0 -or $launcherProcess.ExitCode -ne 0) { throw 'Nonzero normal-close exit code' }
    if (-not (Test-Path -LiteralPath $receipt.log)) { throw 'Owned game launch produced no isolated log' }
    if ($ReadyMarker) {
        # Release file logging may flush only on close. Confirm the ready event
        # from the flushed log, without treating buffering as a game timeout.
        if (-not ([IO.File]::ReadAllText($receipt.log).Contains($ReadyMarker))) { throw 'Ordinary game did not report ready before normal close' }
        $receipt.ready_marker = $ReadyMarker
        $receipt.ready_confirmation = 'Flushed log after normal close; no live marker timestamp claimed'
    }
    if ((Get-Content -LiteralPath $receipt.log -Raw) -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw 'Game launch log contains an engine error' }
    $receipt.exe_sha256 = (Get-FileHash -LiteralPath (Join-Path $folder 'ProjectCrystal.exe')).Hash
    $receipt.pck_sha256 = (Get-FileHash -LiteralPath (Join-Path $folder 'ProjectCrystal.pck')).Hash
    $receipt.passed = $true
    Write-Output "RC3_NORMAL_LAUNCH=PASS seconds=$($receipt.observed_seconds) title=$($receipt.window_title)"
} catch {
    $receipt.error = $_.Exception.Message
    throw
} finally {
    if ($null -ne $game) {
        if (-not $game.HasExited) { $game.CloseMainWindow() | Out-Null; if (-not $game.WaitForExit(5000)) { $game.Kill() } }
        $game.Dispose()
    }
    $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
    $launcherProcess.Dispose()
    Write-Output "RC3_LAUNCHER_EVIDENCE=$output"
}
