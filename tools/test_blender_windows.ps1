[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BuildRoot)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$BuildRoot=(Resolve-Path -LiteralPath $BuildRoot).Path
$build=Get-Content -LiteralPath (Join-Path $BuildRoot 'build_receipt.json') -Raw | ConvertFrom-Json
$output=Join-Path $projectRoot ('artifacts/blender_windows/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$profileRoot=Join-Path $output 'profile'
$localRoot=Join-Path $output 'local'
$tempRoot=Join-Path $output 'temp'
New-Item -ItemType Directory -Force $profileRoot,$localRoot,$tempRoot | Out-Null
$fixtures=@{}
foreach ($row in @(@('p5_tests','legacy_v1.json',1),@('g06_tests','legacy_layout2.json',3))) {
    $source=Get-ChildItem -LiteralPath (Join-Path $projectRoot 'artifacts/godot-user') -Filter restart.json -Recurse | Where-Object { $_.Directory.Name -eq $row[0] } | Select-Object -First 1
    if (-not $source) { throw ('Missing actual generated fixture '+$row[0]) }
    $data=Get-Content -LiteralPath $source.FullName -Raw | ConvertFrom-Json
    if ($data.schema_version -ne $row[2]) { throw 'Fixture has unexpected schema' }
    $destination=Join-Path $profileRoot ('Godot/app_userdata/'+$source.Directory.Parent.Name+'/blender_windows_tests')
    New-Item -ItemType Directory -Force $destination | Out-Null
    Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $destination $row[1])
    $fixtures[$row[1]]=@{source=$source.FullName;sha256=(Get-FileHash -LiteralPath $source.FullName).Hash}
}
$results=@()
foreach ($mode in @('prologue','restart')) {
    $log=Join-Path $output ($mode+'.log')
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$build.qa; $info.WorkingDirectory=Split-Path -Parent $build.qa
    $info.Arguments='--log-file "'+$log+'"'+$(if($mode -eq 'restart'){' -- --reload'}else{''})
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.EnvironmentVariables['APPDATA']=$profileRoot; $info.EnvironmentVariables['LOCALAPPDATA']=$localRoot
    $info.EnvironmentVariables['TEMP']=$tempRoot; $info.EnvironmentVariables['TMP']=$tempRoot
    $info.EnvironmentVariables['CRYSTAL_QA_ISOLATE_JOYPAD_MOTION']='1'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $process=[Diagnostics.Process]::Start($info)
    try {
        if (-not $process.WaitForExit(180000)) { $process.Kill(); throw ('Packaged '+$mode+' exceeded 180 seconds; inspect '+$log) }
        $text=[IO.File]::ReadAllText($log)
        if ($process.ExitCode -ne 0 -or $text -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw ('Packaged '+$mode+' failed; inspect '+$log) }
        if ($text -notmatch 'BLENDER_WINDOWS_RESULT checks=(\d+) failures=0') { throw 'Missing successful packaged result marker' }
        $results+=@{mode=$mode;seconds=$watch.Elapsed.TotalSeconds;checks=[int]$Matches[1];failures=0;log=$log}
    }
    finally { $process.Dispose() }
}
foreach ($record in $fixtures.Values) {
    if ((Get-FileHash -LiteralPath $record.source).Hash -ne $record.sha256) { throw 'Original generated legacy fixture changed' }
}
$required=@('res://scenes/main/blender_windows_candidate.tscn','res://scenes/main/greystone_blender_integration.tscn','res://scenes/world/greystone_blender_master.tscn','res://assets/models/greystone/blender_master/water.glb','res://assets/shaders/greystone/water.gdshader','res://assets/shaders/greystone/ground.gdshader','res://assets/shaders/greystone/rock.gdshader')
$manifest=[ordered]@{base_commit=$build.source_commit;candidate=$build.candidate;qa=$build.qa;profile=$profileRoot;results=$results;fixtures=$fixtures;required_resources=$required;physical_input_acceptance=$false;endurance_acceptance=$false;launcher_status='pending'}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8
$priorPause=$env:CRYSTAL_NO_PAUSE
try {
    $env:CRYSTAL_NO_PAUSE='1'
    $launch=& (Join-Path $PSScriptRoot 'test_rc3_launcher.ps1') -Launcher (Join-Path $BuildRoot 'candidate/start_blender_village.cmd') -ReadyMarker 'BLENDER_WINDOWS_READY' -ObservationSeconds 12
    $line=@($launch | Where-Object { $_ -like 'RC3_LAUNCHER_EVIDENCE=*' })
    if ($line.Count -ne 1) { throw 'Missing ordinary launcher receipt' }
    Copy-Item -LiteralPath (Join-Path $line[0].Substring('RC3_LAUNCHER_EVIDENCE='.Length) 'result.json') -Destination (Join-Path $output 'normal_launch.json')
    $launch | Out-Host
    $manifest.launcher_status='passed'
}
catch { $manifest.launcher_status='failed'; $manifest.error=$_.Exception.Message; throw }
finally {
    $env:CRYSTAL_NO_PAUSE=$priorPause
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding utf8
}
Write-Output ('BLENDER_WINDOWS_TEST_MANIFEST='+(Join-Path $output 'manifest.json'))
