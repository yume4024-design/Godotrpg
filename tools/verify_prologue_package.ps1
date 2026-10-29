param([string]$Root='D:\RPGGAME\builds\prologue-candidate\rc3-20261028', [string]$GodotPath='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference='Stop'
foreach ($role in @('candidate','qa')) {
 $folder=Join-Path $Root $role
 $manifest=Get-Content -LiteralPath (Join-Path $folder 'manifest.json') -Raw | ConvertFrom-Json
 foreach ($file in @('ProjectCrystal.exe','ProjectCrystal.pck')) {
  $actual=(Get-FileHash -LiteralPath (Join-Path $folder $file) -Algorithm SHA256).Hash.ToLowerInvariant()
  $expected=if ($file.EndsWith('.exe')) {$manifest.executable_sha256} else {$manifest.pck_sha256}
  if ($actual -ne $expected) {throw "Package hash mismatch: $role/$file"}
 }
}
$evidence=Join-Path $Root ('acceptance/run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$profile=Join-Path $evidence 'profile'
$tempRoot=Join-Path $evidence 'temp'
New-Item -ItemType Directory -Path $evidence,$profile,$tempRoot -Force | Out-Null
function Run-Pack([string]$Name,[string]$Role,[string[]]$Arguments) {
 $folder=Join-Path $Root $Role
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=Join-Path $folder 'ProjectCrystal.exe'
 if ($Arguments -contains '--script') {
  $info.FileName=$GodotPath
  $Arguments=@('--main-pack',(Join-Path $folder 'ProjectCrystal.pck')) + $Arguments
 }
 $info.Arguments=(@('--log-file',(Join-Path $evidence ($Name+'.log'))) + $Arguments | ForEach-Object {'"{0}"' -f $_}) -join ' '
 $info.WorkingDirectory=$folder
 $info.UseShellExecute=$false
 $info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true
 $info.RedirectStandardError=$true
 $info.EnvironmentVariables['APPDATA']=$profile
 $info.EnvironmentVariables['LOCALAPPDATA']=$profile
 $info.EnvironmentVariables['TEMP']=$tempRoot
 $info.EnvironmentVariables['TMP']=$tempRoot
 $info.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION']='1'
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info
 try {
  if(-not $p.Start()){throw 'Failed start'}
  $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  if(-not $p.WaitForExit(180000)){$p.Kill();throw "$Name timed out"}
  $output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
  $output | Set-Content -LiteralPath (Join-Path $evidence ($Name+'-output.txt')) -Encoding utf8
  if($p.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|FAIL |Failed loading resource)'){throw "$Name failed"}
  if ($Name -eq 'qa-mine-edges') {
   if ($output -notmatch 'MINE_EDGE_RESULT samples=23 new_gaps=0 failures=0') {throw 'Missing successful mine edge result'}
  } elseif ($Name -ne 'candidate-launch' -and $output -notmatch '_RESULT checks=\d+ failures=0') {throw "Missing $Name result"}
  Write-Output "PACKAGE_TEST=$Name PASS"
  $output -split "`n" | Where-Object {$_ -match '_RESULT '}
 } finally {$p.Dispose()}
}
Run-Pack 'qa-story' 'qa' @()
Run-Pack 'qa-reload' 'qa' @('--','--reload')
Run-Pack 'qa-navigation' 'qa' @('--script','res://tests/prologue_navigation_test.gd')
Run-Pack 'qa-area-map' 'qa' @('--script','res://tests/prologue_area_map_test.gd')
Run-Pack 'qa-mine-edges' 'qa' @('--script','res://tests/mine_edge_safety_test.gd')
Run-Pack 'qa-legacy-fixture' 'qa' @('--headless','--script','res://tests/phase5_prologue_test.gd')
Run-Pack 'qa-g06-fixture' 'qa' @('--headless','--script','res://tests/greystone_integration_test.gd')
Run-Pack 'qa-migration' 'qa' @('--headless','--script','res://tests/prologue_migration_test.gd')
Run-Pack 'qa-migration-reload' 'qa' @('--headless','--script','res://tests/prologue_migration_test.gd','--','--reload')
Run-Pack 'qa-commerce' 'qa' @('--headless','--script','res://tests/prologue_commerce_test.gd')
Run-Pack 'qa-commerce-reload' 'qa' @('--headless','--script','res://tests/prologue_commerce_test.gd','--','--reload')
Run-Pack 'qa-collision-snapshot' 'qa' @('--headless','--script','res://tests/location_collision_snapshot_test.gd')
Run-Pack 'candidate-launch' 'candidate' @('--quit-after','180')
