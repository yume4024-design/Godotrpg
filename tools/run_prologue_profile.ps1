param([Parameter(Mandatory=$true)][string]$Build)
$ErrorActionPreference='Stop'
$Build=(Resolve-Path -LiteralPath $Build).Path
$run=Join-Path $Build ('run-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$profile=Join-Path $run 'profile'
New-Item -ItemType Directory -Path $run,$profile | Out-Null
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=Join-Path $Build 'ProjectCrystal.exe';$info.WorkingDirectory=$Build
$info.Arguments='--log-file "'+(Join-Path $run 'native.log')+'"'
$info.UseShellExecute=$false;$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$info.EnvironmentVariables['APPDATA']=$profile;$info.EnvironmentVariables['LOCALAPPDATA']=$profile
$info.EnvironmentVariables['TEMP']=$run;$info.EnvironmentVariables['TMP']=$run
$info.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION']='1'
$p=[Diagnostics.Process]::new();$p.StartInfo=$info
$watch=[Diagnostics.Stopwatch]::StartNew();$started=$false
$record=[ordered]@{build=$Build;pid=$null;passed=$false;kind='Short native Release performance diagnostic, not soak or human acceptance'}
$csv=Join-Path $run 'process.csv'
'seconds,working_set_bytes,private_bytes' | Set-Content -LiteralPath $csv
try {
 if(-not $p.Start()){throw 'Could not start release probe'};$started=$true;$record.pid=$p.Id
 $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
 Write-Output "PROLOGUE_PROFILE_RUNNING=$run PID=$($p.Id)"
 while(-not $p.HasExited){
  $p.Refresh()
  ('{0:F3},{1},{2}' -f $watch.Elapsed.TotalSeconds,$p.WorkingSet64,$p.PrivateMemorySize64) | Add-Content -LiteralPath $csv
  if($watch.Elapsed.TotalSeconds -gt 240){throw 'Release performance probe exceeded 240 seconds'}
  [void]$p.WaitForExit(5000)
 }
 $record.exit_code=$p.ExitCode
 $output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
 $output | Set-Content -LiteralPath (Join-Path $run 'output.txt') -Encoding utf8
 $log=Get-Content -LiteralPath (Join-Path $run 'native.log') -Raw
 if($p.ExitCode -ne 0 -or ($output+$log) -match '(?im)^\s*(ERROR:|SCRIPT ERROR:|FAIL |Parse Error:)'){throw 'Release probe failed; inspect native log'}
 $reports=@(Get-ChildItem -LiteralPath $profile -Recurse -Filter report.json | Where-Object {$_.Directory.Name -eq 'prologue_profile'})
 if($reports.Count -ne 1){throw 'Missing unique probe report'}
 $r=Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
 if(-not $r.release -or $r.display -ne 'Windows' -or $r.failures -ne 0 -or $r.timed_methods.Count -eq 0){throw 'Release/profile contract failed'}
 Copy-Item -LiteralPath $reports[0].FullName -Destination (Join-Path $run 'report.json')
 Copy-Item -LiteralPath (Join-Path $reports[0].Directory.FullName 'final.webp') -Destination (Join-Path $run 'final.webp')
 $record.passed=$true
 Write-Output "PROLOGUE_PROFILE_PASS checks=$($r.checks) seconds=$($r.seconds)"
} finally {
 if($started -and -not $p.HasExited){$p.Kill();[void]$p.WaitForExit(5000)}
 $record.seconds=$watch.Elapsed.TotalSeconds
 $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'run.json') -Encoding utf8
 $p.Dispose()
}
