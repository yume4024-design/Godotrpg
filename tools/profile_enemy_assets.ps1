[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Exe, [ValidateSet("spore_sprite","ore_beetle","thorn_boar")][string]$Asset = "spore_sprite")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$output = Join-Path $projectRoot ('artifacts/a04-performance/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$profile = Join-Path $output 'profile'
$local = Join-Path $output 'local'
$temp = Join-Path $output 'temp'
New-Item -ItemType Directory -Force $profile,$local,$temp | Out-Null
$log = Join-Path $output 'release.log'
$csv = Join-Path $output 'process.csv'
'elapsed_seconds,working_set_bytes,private_bytes,peak_working_set_bytes' | Set-Content -LiteralPath $csv
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $Exe
$info.Arguments = '--log-file "' + $log + '" -- --asset=' + $Asset
$info.WorkingDirectory = Split-Path -Parent $Exe
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.EnvironmentVariables['APPDATA'] = $profile
$info.EnvironmentVariables['LOCALAPPDATA'] = $local
$info.EnvironmentVariables['TEMP'] = $temp
$info.EnvironmentVariables['TMP'] = $temp
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = [Diagnostics.Process]::Start($info)
Write-Output "A04_EVIDENCE=$output PID=$($process.Id)"
try {
    while (-not $process.WaitForExit(1000)) {
        if ($watch.Elapsed.TotalSeconds -gt 60) { $process.Kill(); throw 'A04 native performance test exceeded 60 seconds' }
        $process.Refresh()
        if (-not $process.HasExited) {
            ('{0:F3},{1},{2},{3}' -f $watch.Elapsed.TotalSeconds,$process.WorkingSet64,$process.PrivateMemorySize64,$process.PeakWorkingSet64) | Add-Content -LiteralPath $csv
        }
    }
    $metrics = @(Get-ChildItem -LiteralPath $profile -Recurse -Filter metrics.json | Where-Object {$_.Directory.Name -eq 'a04_enemy_perf'})
    if ($metrics.Count -ne 1) { throw 'Missing unique A04 metrics' }
    $data = Get-Content -LiteralPath $metrics[0].FullName -Raw | ConvertFrom-Json
    $text = Get-Content -LiteralPath $log -Raw
    $receipt = [ordered]@{asset=$Asset;source_commit=(git -C $projectRoot rev-parse HEAD);dirty_files=@(git -c core.safecrlf=false -C $projectRoot diff --name-only);exe=$Exe;pck_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($Exe,'.pck'))).Hash;pid=$process.Id;seconds=$watch.Elapsed.TotalSeconds;exit_code=$process.ExitCode;metrics=$metrics[0].FullName;scope='Native Release combat fixture; not full-game soak or physical input';android_verified=$false}
    $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8
    if ($process.ExitCode -ne 0 -or $text -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw "A04 runtime failed: $log" }
    if ($data.asset -ne $Asset) { throw "Wrong enemy asset measured" }
    if (-not $data.release -or $data.display -eq 'headless' -or $data.failures.Count -ne 0 -or $data.cases.Count -ne 2) { throw 'A04 Release gates failed' }
    foreach ($case in $data.cases) { if ($case.frames -ne 600) { throw 'A04 frame sample count mismatch' } }
    Write-Output "A04_RELEASE_RESULT checks=$($data.checks) failures=0 seconds=$($watch.Elapsed.TotalSeconds)"
    Write-Output "A04_MANIFEST=$(Join-Path $output 'manifest.json')"
} finally { $process.Dispose() }
