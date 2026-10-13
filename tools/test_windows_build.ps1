[CmdletBinding()]
param([ValidateSet('Smoke','QA','Reload')][string]$Mode = 'Smoke')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$folder = if ($Mode -eq 'Smoke') { 'windows' } else { 'qa' }
$buildRoot = Join-Path $projectRoot ('builds/' + $folder)
$executable = Join-Path $buildRoot 'ProjectCrystal.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw 'Export the matching Windows preset first.' }
$logPath = Join-Path $projectRoot ('artifacts/logs/exported-{0}-{1}.log' -f $Mode.ToLowerInvariant(), (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$arguments = @('--log-file', $logPath)
if ($Mode -eq 'Smoke') { $arguments += @('--quit-after', '180') }
else {
    $arguments += @('--', ('--evidence-dir=' + (Join-Path $projectRoot 'artifacts/phase6-export')))
    if ($Mode -eq 'Reload') { $arguments += '--reload' }
}
$profileRoot = Join-Path $projectRoot 'artifacts/export-test-user'
New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
$info = [System.Diagnostics.ProcessStartInfo]::new()
$info.FileName = $executable
$info.WorkingDirectory = $buildRoot
$info.Arguments = ($arguments | ForEach-Object { '"{0}"' -f $_ }) -join ' '
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.EnvironmentVariables['APPDATA'] = $profileRoot
$info.EnvironmentVariables['LOCALAPPDATA'] = $profileRoot
$info.EnvironmentVariables['TEMP'] = (Join-Path $projectRoot 'artifacts/godot-tmp')
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $info
try {
    if (-not $process.Start()) { throw 'Exported game failed to start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Exported test timed out.' }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    Write-Output $output
    if ($process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:)') { throw 'Exported runtime reported a failure.' }
    Write-Output "Passed $Mode. Log: $logPath"
} finally { $process.Dispose() }
