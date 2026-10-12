[CmdletBinding()]
param(
    [ValidateSet('Version', 'Check', 'Smoke', 'Test', 'TestPhase2', 'VisualPhase2', 'TestPhase3', 'VisualPhase3', 'PreviewBattle', 'Editor', 'Run')]
    [string]$Mode = 'Version',
    [string]$GodotPath = $env:GODOT_PATH
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Pass -GodotPath with an executable file."
}
if ($Mode -ne 'Version' -and -not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot') -PathType Leaf)) {
    throw 'project.godot is not present. Implement Phase 1 before checking or running the game.'
}

$profileRoot = Join-Path $projectRoot 'artifacts\godot-user'
$cacheRoot = Join-Path $projectRoot 'artifacts\godot-local'
New-Item -ItemType Directory -Path $profileRoot, $cacheRoot -Force | Out-Null

$engineArgs = @('--version')
if ($Mode -ne 'Version') {
    $logRoot = Join-Path $projectRoot 'artifacts\logs'
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $logPath = Join-Path $logRoot ('{0}-{1}.log' -f $Mode.ToLowerInvariant(), (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    $engineArgs = @('--path', $projectRoot, '--log-file', $logPath)
    if ($Mode -in @('Check', 'Smoke', 'Test', 'TestPhase2', 'TestPhase3')) { $engineArgs += '--headless' }
    if ($Mode -eq 'Check') { $engineArgs += '--import' }
    if ($Mode -eq 'Smoke') { $engineArgs += @('--quit-after', '120') }
    if ($Mode -eq 'Test') { $engineArgs += @('--script', 'res://tests/phase1_movement_test.gd') }
    if ($Mode -in @('TestPhase2', 'VisualPhase2')) { $engineArgs += @('--script', 'res://tests/phase2_exploration_test.gd') }
    if ($Mode -in @('TestPhase3', 'VisualPhase3', 'PreviewBattle')) { $engineArgs += @('--script', 'res://tests/phase3_battle_test.gd') }
    if ($Mode -eq 'PreviewBattle') { $engineArgs += @('--', '--manual') }
    if ($Mode -eq 'Editor') { $engineArgs += '--editor' }
}

# Quote each argument independently for Windows PowerShell and PowerShell 7.
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $GodotPath
$startInfo.Arguments = ($engineArgs | ForEach-Object { '"{0}"' -f $_ }) -join ' '
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.EnvironmentVariables['APPDATA'] = $profileRoot
$startInfo.EnvironmentVariables['LOCALAPPDATA'] = $cacheRoot
if ($Mode -in @('Editor', 'Run', 'PreviewBattle')) {
    # Use the graphical binary for detached windows. The console wrapper inherits
    # the caller's pipe handles and can stall after a short-lived tool shell exits.
    $graphicalPath = $GodotPath -replace '_console\.exe$', '.exe'
    if (Test-Path -LiteralPath $graphicalPath -PathType Leaf) {
        $startInfo.FileName = $graphicalPath
    }
    $launched = [System.Diagnostics.Process]::Start($startInfo)
    Write-Output "Started $Mode (PID $($launched.Id)). Log: $logPath"
    $launched.Dispose()
    return
}
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
try {
    if (-not $process.Start()) { throw 'Godot process did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'Godot exceeded the 60 second timeout. Inspect the log before retrying.'
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $output = $stdout + [Environment]::NewLine + $stderr
    Write-Output $output.Trim()
    if ($process.ExitCode -ne 0) { throw "Godot exited with code $($process.ExitCode)." }
    if ($output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
        throw 'Godot reported an error despite its exit code. Inspect the output and log.'
    }
    if ($Mode -ne 'Version') { Write-Output "Log: $logPath" }
} finally {
    $process.Dispose()
}
