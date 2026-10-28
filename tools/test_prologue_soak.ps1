param(
 [string]$Root='D:\RPGGAME\builds\prologue-candidate\rc3-20261028',
 [string]$GodotPath='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$qa=Join-Path $Root 'qa'
$qaManifest=Get-Content -LiteralPath (Join-Path $qa 'manifest.json') -Raw | ConvertFrom-Json
$engineVersion=(& $GodotPath --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $engineVersion -ne $qaManifest.engine){throw 'Godot version must match the fixed package manifest'}
$hashes=@{}
foreach ($role in @('candidate','qa')) {
 $folder=Join-Path $Root $role
 $manifest=Get-Content -LiteralPath (Join-Path $folder 'manifest.json') -Raw | ConvertFrom-Json
 if($manifest.source_commit -ne $qaManifest.source_commit -or $manifest.engine -ne $engineVersion -or $manifest.version -ne $qaManifest.version){throw 'Candidate and QA package manifests do not match'}
 foreach ($name in @('ProjectCrystal.exe','ProjectCrystal.pck')) {
  $path=Join-Path $folder $name
  $sha=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  $expected=if($name.EndsWith('.exe')){$manifest.executable_sha256}else{$manifest.pck_sha256}
  if($sha -ne $expected){throw "Package identity mismatch: $role/$name"}
  $hashes[$path]=$sha
 }
}
$run=Join-Path $Root ('acceptance/soak-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$profile=Join-Path $run 'profile'
$tempRoot=Join-Path $run 'temp'
New-Item -ItemType Directory -Path $run,$profile,$tempRoot | Out-Null
foreach($name in @('prologue_rc2_stability_test.gd','prologue_rc2_restart_test.gd')) {
 Copy-Item -LiteralPath (Join-Path $projectRoot "tests/$name") -Destination (Join-Path $run $name)
}
$result=[ordered]@{version=$qaManifest.version;source_commit=$qaManifest.source_commit;package_hashes=$hashes;method='Graphical Godot console engine mounts fixed QA PCK; external test only; not a standalone release EXE benchmark or human playthrough';passed=$false;runs=@()}
function Run-Native([string]$Name,[string[]]$UserArgs,[int]$Limit) {
 $script=if($Name -eq 'soak'){'prologue_rc2_stability_test.gd'}else{'prologue_rc2_restart_test.gd'}
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$GodotPath;$info.WorkingDirectory=$qa;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $arguments=@('--main-pack',(Join-Path $qa 'ProjectCrystal.pck'),'--log-file',(Join-Path $run "$Name.log"),'--script',(Join-Path $run $script),'--')+$UserArgs
 $info.Arguments=($arguments | ForEach-Object {'"{0}"' -f $_}) -join ' '
 $info.EnvironmentVariables['APPDATA']=$profile;$info.EnvironmentVariables['LOCALAPPDATA']=$profile
 $info.EnvironmentVariables['TEMP']=$tempRoot;$info.EnvironmentVariables['TMP']=$tempRoot
 $info.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION']='1'
 $csv=Join-Path $run "$Name-process.csv"
 'seconds,working_set_bytes,private_bytes,peak_working_set_bytes,cpu_seconds' | Set-Content -LiteralPath $csv
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info;$watch=[Diagnostics.Stopwatch]::StartNew()
 $metricProcess=$null
 $entry=[ordered]@{name=$Name;samples=0;script_sha256=(Get-FileHash -LiteralPath (Join-Path $run $script)).Hash;started_utc=[DateTime]::UtcNow.ToString('o');pid=$null;exit_code=$null}
 try {
  if(-not $p.Start()){throw 'Native process failed to start'}
  $entry.pid=$p.Id
  $expectedChild=[IO.Path]::GetFileName($GodotPath).Replace("_console.exe",".exe")
  $result.runs+=,$entry
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'run.json') -Encoding utf8
  $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
  Write-Output "PROLOGUE_SOAK_RUN=$run MODE=$Name PID=$($p.Id)"
  while(-not $p.HasExited) {
   $p.Refresh()
   if($null -eq $metricProcess) {
    if($GodotPath.EndsWith('_console.exe')) {
     $children=@(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | Where-Object {$_.Name -eq $expectedChild})
     if($children.Count -eq 1){$metricProcess=[Diagnostics.Process]::GetProcessById($children[0].ProcessId)}
    } else {$metricProcess=$p}
    if($null -ne $metricProcess){$entry.metrics_pid=$metricProcess.Id;$entry.metrics_name=$metricProcess.ProcessName}
   }
   if($null -ne $metricProcess) {
    $metricProcess.Refresh()
    if(-not $metricProcess.HasExited) {
     ('{0:F3},{1},{2},{3},{4:F3}' -f $watch.Elapsed.TotalSeconds,$metricProcess.WorkingSet64,$metricProcess.PrivateMemorySize64,$metricProcess.PeakWorkingSet64,$metricProcess.TotalProcessorTime.TotalSeconds) | Add-Content -LiteralPath $csv
     $entry.samples++
    }
   }
   if($watch.Elapsed.TotalSeconds -gt $Limit){throw "Native $Name exceeded $Limit seconds"}
   [void]$p.WaitForExit(5000)
  }
  $entry.exit_code=$p.ExitCode
  $text=$out.GetAwaiter().GetResult()+$err.GetAwaiter().GetResult()
  $text | Set-Content -LiteralPath (Join-Path $run "$Name-output.txt") -Encoding utf8
  if($p.ExitCode -ne 0 -or $text -match '(?im)^\s*(ERROR:|SCRIPT ERROR:|FAIL |Parse Error:)'){throw "Native $Name failed; inspect evidence"}
  if($entry.samples -eq 0){throw 'No rendering process memory samples; launcher metrics are not valid'}
  $text -split "`n" | Where-Object {$_ -match 'RESULT|OBSERVATION|SOAK_STARTED'} | Write-Output
 } finally {
  # Stop only the processes started by this invocation if a timeout/error interrupted them.
  if($null -ne $metricProcess -and -not $metricProcess.HasExited){$metricProcess.Kill();[void]$metricProcess.WaitForExit(5000)}
  if($null -ne $entry.pid -and -not $p.HasExited){$p.Kill();[void]$p.WaitForExit(5000)}
  $entry.seconds=$watch.Elapsed.TotalSeconds;$entry.ended_utc=[DateTime]::UtcNow.ToString('o')
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'run.json') -Encoding utf8
  if($null -ne $metricProcess -and $metricProcess.Id -ne $p.Id){$metricProcess.Dispose()}
  $p.Dispose()
 }
}
try {
 Run-Native 'soak' @("--tested-source=$($qaManifest.source_commit)","--tested-package=$($qaManifest.version) QA PCK","--tested-pck-sha=$($qaManifest.pck_sha256)") 2250
 $reports=@(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter report.json | Where-Object {$_.Directory.Name -eq 'prologue_rc2_soak'})
 if($reports.Count -ne 1){throw 'Missing unique soak report'}
 $report=Get-Content -LiteralPath $reports[0].FullName -Raw | ConvertFrom-Json
 if(-not $report.complete -or $report.soak_seconds -lt 1800 -or $report.failures -ne 0 -or $report.display -eq 'headless'){throw 'Rendered 30 minute gate failed'}
 Copy-Item -LiteralPath $reports[0].FullName -Destination (Join-Path $run 'metrics.json')
 $saves=@(Get-ChildItem -LiteralPath $reports[0].Directory.FullName -File -Filter '*soak*.json*')
 $saveHashes=@{};foreach($file in $saves){$saveHashes[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName).Hash}
 Run-Native 'restart' @('--reload') 180
 foreach($path in $saveHashes.Keys){if((Get-FileHash -LiteralPath $path).Hash -ne $saveHashes[$path]){throw 'Restart changed soak save'}}
 $result.restart_save_hashes=$saveHashes
 foreach($path in $hashes.Keys){if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -ne $hashes[$path]){throw 'Package changed during soak'}}
 $result.passed=$true
} catch {$result.error=$_.Exception.Message;throw} finally {
 $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'run.json') -Encoding utf8
 Write-Output "PROLOGUE_SOAK_EVIDENCE=$run"
}
