[CmdletBinding()]
param([string]$BuildDirectory = '',[switch]$VerboseRuntime)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $latest = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'builds/greystone-preview') -Directory |
        Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) { throw 'Run ExportGreystonePreview first.' }
    $BuildDirectory = $latest.FullName
}
$profileRoot = Join-Path $projectRoot 'artifacts/greystone-export-user'
$captureRoot = Join-Path $projectRoot ('artifacts/greystone-export-capture/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$logRoot = Join-Path $projectRoot 'artifacts/logs'
$tempRoot = Join-Path $projectRoot 'artifacts/godot-tmp'
New-Item -ItemType Directory -Path $profileRoot,$captureRoot,$logRoot,$tempRoot -Force | Out-Null
$logPath = Join-Path $logRoot ('greystone-export-smoke-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$info = [System.Diagnostics.ProcessStartInfo]::new()
$info.FileName = Join-Path $BuildDirectory 'ProjectCrystal.exe'
$info.WorkingDirectory = $BuildDirectory
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
foreach ($argument in @('--log-file',$logPath,'--write-movie',(Join-Path $captureRoot 'startup.png'),'--fixed-fps','30')) {
    $info.ArgumentList.Add($argument)
}
if ($VerboseRuntime) { $info.ArgumentList.Add('--verbose') }
$info.ArgumentList.Add('--')
$info.ArgumentList.Add('--preview-smoke')
$info.EnvironmentVariables['APPDATA'] = $profileRoot
$info.EnvironmentVariables['LOCALAPPDATA'] = $profileRoot
$info.EnvironmentVariables['TEMP'] = $tempRoot
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $info
try {
    if (-not $process.Start()) { throw 'Preview executable failed to start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Preview capture timed out.' }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    Set-Content -LiteralPath ($logPath + '.console.txt') -Value $output -Encoding utf8
    Write-Output $output
    if ($process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:)') { throw "Preview failed: $logPath" }
    $frames = @(Get-ChildItem -LiteralPath $captureRoot -Filter '*.png' -File)
    if ($frames.Count -lt 60) { throw "Expected 60 rendered frames, found $($frames.Count)." }
    [pscustomobject]@{Build=$BuildDirectory;Log=$logPath;Frames=$frames.Count;CaptureDirectory=$captureRoot}
} finally { $process.Dispose() }
