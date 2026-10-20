[CmdletBinding()]
param([string]$CandidateExe = '', [switch]$Smoke)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CandidateExe)) {
    $adjacent = Join-Path $PSScriptRoot 'ProjectCrystal.exe'
    $CandidateExe = if (Test-Path -LiteralPath $adjacent) { $adjacent } else { Join-Path (Split-Path -Parent $PSScriptRoot) 'builds/g08/rc3-20261020/candidate/ProjectCrystal.exe' }
}
$CandidateExe = (Resolve-Path -LiteralPath $CandidateExe).Path
$folder = Split-Path -Parent $CandidateExe
$testRoot = Join-Path $folder 'user_test'
$profile = Join-Path $testRoot 'profile'
$local = Join-Path $testRoot 'local'
$temp = Join-Path $testRoot 'temp'
New-Item -ItemType Directory -Force $profile,$local,$temp | Out-Null
$log = Join-Path $testRoot ('play-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $CandidateExe
$info.Arguments = '--log-file "' + $log + '"' + $(if ($Smoke) { ' -- --preview-smoke' } else { '' })
$info.WorkingDirectory = $folder
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.EnvironmentVariables['APPDATA'] = $profile
$info.EnvironmentVariables['LOCALAPPDATA'] = $local
$info.EnvironmentVariables['TEMP'] = $temp
$info.EnvironmentVariables['TMP'] = $temp
$process = [Diagnostics.Process]::Start($info)
try {
    Write-Output "RC3_PID=$($process.Id) PROFILE=$profile LOG=$log"
    if ($Smoke) {
        if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'RC3 smoke exceeded 15 seconds' }
        if ($process.ExitCode -ne 0) { throw "RC3 smoke exit=$($process.ExitCode)" }
        if ((Get-Content -LiteralPath $log -Raw) -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw 'RC3 smoke reported an engine error' }
        Write-Output 'RC3_ISOLATED_SMOKE=PASS'
    }
} finally { $process.Dispose() }
