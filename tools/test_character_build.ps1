[CmdletBinding()]
param(
    [ValidateSet('Full','Reload')][string]$Mode = 'Full',
    [string]$BuildDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $latest = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'builds/character-qa') -Directory |
        Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) { throw 'Run ExportCharacterQA first.' }
    $BuildDirectory = $latest.FullName
}
$executable = Join-Path $BuildDirectory 'ProjectCrystal.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Character QA executable missing.' }
$profileRoot = Join-Path $projectRoot 'artifacts/character-export-user'
$tempRoot = Join-Path $projectRoot 'artifacts/godot-tmp'
$logRoot = Join-Path $projectRoot 'artifacts/logs'
New-Item -ItemType Directory -Path $profileRoot,$tempRoot,$logRoot -Force | Out-Null
$logPath = Join-Path $logRoot ('character-export-{0}-{1}.log' -f $Mode.ToLowerInvariant(),(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$arguments = @('--log-file',$logPath)
if ($Mode -eq 'Reload') { $arguments += @('--','--reload') }
$info = [System.Diagnostics.ProcessStartInfo]::new()
$info.FileName = $executable
$info.WorkingDirectory = $BuildDirectory
foreach ($argument in $arguments) { $info.ArgumentList.Add($argument) }
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.EnvironmentVariables['APPDATA'] = $profileRoot
$info.EnvironmentVariables['LOCALAPPDATA'] = $profileRoot
$info.EnvironmentVariables['TEMP'] = $tempRoot
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $info
try {
    if (-not $process.Start()) { throw 'Character QA failed to start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Character QA timed out.' }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    Write-Output $output
    if ($process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|FAIL )') {
        throw "Character QA failed. Inspect $logPath"
    }
    if ($output -notmatch 'G06_STORY_RESULT checks=\d+ failures=0') { throw 'Missing completed story result.' }
    Write-Output "Passed $Mode. Build: $BuildDirectory. Log: $logPath"
} finally { $process.Dispose() }
