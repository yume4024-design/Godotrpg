[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$GodotPath='D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference='Stop'
$evidence=Join-Path $Root ('acceptance/pack-audit-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$hostRoot=Join-Path $evidence 'empty-host'
$profile=Join-Path $evidence 'profile'
New-Item -ItemType Directory -Path $hostRoot,$profile -Force | Out-Null
'config_version=5' | Set-Content (Join-Path $hostRoot 'project.godot') -Encoding ascii
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'audit_windows_pack.gd') -Destination (Join-Path $hostRoot 'audit.gd')
$required=@(
 'res://scenes/main/prologue_candidate.tscn',
 'res://scenes/world/greystone_village.tscn',
 'res://scripts/ui/area_map_panel.gd',
 'res://scripts/save/location_collision_snapshot.gd',
 'res://assets/models/rebuilt_characters/ren_runtime.glb',
 'res://assets/models/pixal3d/lia_rigged.glb'
) -join ','
$inventories=@{}
foreach($role in @('candidate','qa')) {
 $pck=Join-Path (Join-Path $Root $role) 'ProjectCrystal.pck'
 $jsonPath=Join-Path $evidence ($role+'.json')
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$GodotPath
 $info.Arguments=(@('--headless','--path',$hostRoot,'--script','res://audit.gd','--',$pck,$jsonPath,$required) | ForEach-Object { '"{0}"' -f $_ }) -join ' '
 $info.WorkingDirectory=$hostRoot
 $info.UseShellExecute=$false
 $info.CreateNoWindow=$true
 $info.RedirectStandardOutput=$true
 $info.RedirectStandardError=$true
 foreach($name in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) { $info.EnvironmentVariables[$name]=$profile }
 $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
 try {
  if(-not $process.Start()){throw 'Pack audit did not start'}
  $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
  if(-not $process.WaitForExit(120000)){$process.Kill();throw 'Pack audit timed out'}
  $output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
  $output | Set-Content (Join-Path $evidence ($role+'-output.txt')) -Encoding utf8
  if($process.ExitCode -ne 0 -or $output -match '(?im)^\s*(ERROR:|SCRIPT ERROR:|Parse Error:)'){throw "Pack audit failed: $role"}
  $inventories[$role]=Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
 } finally { $process.Dispose() }
}
$differences=[Collections.Generic.List[string]]::new()
$exceptions=@('res://project.binary','res://.godot/global_script_class_cache.cfg','res://.godot/uid_cache.bin')
$compared=0
foreach($role in @('candidate','qa')) {
 foreach($entry in $inventories[$role].required.PSObject.Properties) {
  if(-not $entry.Value){$differences.Add("Missing required resource in $role : $($entry.Name)")}
 }
}
foreach($entry in $inventories.candidate.files.PSObject.Properties) {
 if($entry.Name -in $exceptions){continue}
 if($entry.Name -match '^res://(tests|source_assets|tools|docs|artifacts|builds)/') {
  $differences.Add("Unexpected candidate content: $($entry.Name)")
 }
 $other=$inventories.qa.files.PSObject.Properties[$entry.Name]
 if($null -eq $other -or $entry.Value -ne $other.Value){$differences.Add("Runtime payload differs: $($entry.Name)")}
 $compared++
}
if($compared -lt 500){$differences.Add('Implausibly small resource inventory')}
$result=[ordered]@{
 candidate_entries=@($inventories.candidate.files.PSObject.Properties).Count
 qa_entries=@($inventories.qa.files.PSObject.Properties).Count
 compared_entries=$compared; allowed_configuration_differences=$exceptions
 failures=$differences.ToArray(); passed=($differences.Count -eq 0)
 method='Fresh empty host; native PCK enumeration includes hidden imported/exported bytes, with ResourceLoader checks.'
}
$result | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $evidence 'comparison.json') -Encoding utf8
Write-Output "PACK_COMPARISON=$($result.passed) compared=$compared evidence=$evidence"
if(-not $result.passed){throw ($differences -join "`n")}
