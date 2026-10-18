[CmdletBinding()]
param([string]$CandidateExe = '', [string]$QaExe = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$evidenceRoot = Join-Path $projectRoot ('artifacts/g08/' + $stamp)
$profileRoot = Join-Path $evidenceRoot 'profile'
$localRoot = Join-Path $evidenceRoot 'local'
New-Item -ItemType Directory -Force $evidenceRoot,$profileRoot,$localRoot | Out-Null
$results = [Collections.Generic.List[object]]::new()
$manifestPath = Join-Path $evidenceRoot 'manifest.json'

function Invoke-Package([string]$Exe, [string]$Label, [string[]]$UserArguments) {
    $log = Join-Path $evidenceRoot ($Label + '.log')
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Exe
    $arguments = @('--log-file', $log)
    if ($UserArguments.Count) { $arguments += '--'; $arguments += $UserArguments }
    $info.Arguments = ($arguments | ForEach-Object { '"{0}"' -f $_ }) -join ' '
    $info.WorkingDirectory = Split-Path -Parent $Exe
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.EnvironmentVariables['APPDATA'] = $profileRoot
    $info.EnvironmentVariables['LOCALAPPDATA'] = $localRoot
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($info)
    try {
        if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "$Label exceeded 60 seconds" }
        $text = if (Test-Path $log) { Get-Content $log -Raw } else { throw "Missing $Label log" }
        if ($process.ExitCode -ne 0 -or $text -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
            throw "$Label failed; see $log"
        }
        $result = @($text -split "`r?`n" | Where-Object { $_ -match '_RESULT' })
        if ($Label -ne 'candidate-smoke' -and $result.Count -eq 0) { throw "Missing QA result marker" }
        $results.Add([pscustomobject]@{label=$Label;seconds=$watch.Elapsed.TotalSeconds;exit_code=$process.ExitCode;log=$log;result=$result})
        $results | ConvertTo-Json -Depth 5 | Set-Content $manifestPath -Encoding utf8
        Write-Output "$Label exit=0 $($result -join '; ')"
    } finally { $process.Dispose() }
}

& (Join-Path $PSScriptRoot 'godot.ps1') -Mode Check | Out-Host
$packages = @{}
if ($CandidateExe -and $QaExe) {
    $packages.ExportG08Candidate = (Resolve-Path -LiteralPath $CandidateExe).Path
    $packages.ExportG08QA = (Resolve-Path -LiteralPath $QaExe).Path
} else {
foreach ($mode in @('ExportG08Candidate','ExportG08QA')) {
    $output = & (Join-Path $PSScriptRoot 'godot.ps1') -Mode $mode
    $line = @($output -split "`r?`n" | Where-Object { $_ -like 'G08_EXPORT_PATH=*' })
    if ($line.Count -ne 1) { throw "Missing export path for $mode" }
    $packages[$mode] = $line[0].Substring('G08_EXPORT_PATH='.Length)
    Write-Output "$mode $($packages[$mode])"
}
}
 $legacyRoot = Join-Path $projectRoot 'artifacts/godot-user'
 $legacy = Get-ChildItem $legacyRoot -Filter restart.json -Recurse | Where-Object { $_.Directory.Name -eq 'p5_tests' } | Select-Object -First 1
 if (-not $legacy) {
     & (Join-Path $PSScriptRoot 'godot.ps1') -Mode TestPhase5 | Out-Host
     $legacy = Get-ChildItem $legacyRoot -Filter restart.json -Recurse | Where-Object { $_.Directory.Name -eq 'p5_tests' } | Select-Object -First 1
 }
 if (-not $legacy) { throw 'Missing generated v1 test fixture' }
 $legacyData = Get-Content $legacy.FullName -Raw | ConvertFrom-Json
 if ($legacyData.schema_version -ne 1 -or $legacyData.content_version -ne 'CH00-P5') { throw 'Unexpected legacy test fixture' }
 $legacyDestination = Join-Path $profileRoot ('Godot/app_userdata/' + $legacy.Directory.Parent.Name + '/g08_tests/legacy_v1.json')
 New-Item -ItemType Directory -Force (Split-Path -Parent $legacyDestination) | Out-Null
 Copy-Item -LiteralPath $legacy.FullName -Destination $legacyDestination
Invoke-Package $packages.ExportG08Candidate 'candidate-smoke' @('--preview-smoke')
Invoke-Package $packages.ExportG08QA 'qa-prologue' @()
Invoke-Package $packages.ExportG08QA 'qa-restart' @('--reload')
$summary = [ordered]@{base_commit=(git -C $projectRoot rev-parse HEAD);candidate=$packages.ExportG08Candidate;qa=$packages.ExportG08QA;profile=$profileRoot;legacy_fixture_sha256=(Get-FileHash $legacy.FullName).Hash;results=$results.ToArray()}
$summary | ConvertTo-Json -Depth 6 | Set-Content $manifestPath -Encoding utf8
foreach ($role in @('ExportG08Candidate','ExportG08QA')) {
    $folder = Split-Path -Parent $packages[$role]
    Copy-Item (Join-Path $projectRoot 'docs/ASSET_CREDITS.md') $folder
    Copy-Item (Join-Path $projectRoot 'docs/GODOT_LICENSES.txt') $folder
    Get-ChildItem $folder -File | Where-Object Name -ne 'SHA256.json' | ForEach-Object {
        [pscustomobject]@{file=$_.Name;sha256=(Get-FileHash $_.FullName).Hash;bytes=$_.Length}
    } | ConvertTo-Json | Set-Content (Join-Path $folder 'SHA256.json') -Encoding utf8
}
Write-Output "G08_PACKAGE_MANIFEST=$manifestPath"
