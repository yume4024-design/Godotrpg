[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$BuildRoot,
    [ValidateSet('candidate','qa','qa-soak')][string[]]$Roles=@('candidate','qa'),
    [ValidateSet('Blender','Mine')][string]$CandidateFamily='Blender',
    [string]$GodotPath='D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$BuildRoot=[IO.Path]::GetFullPath($BuildRoot)
if ($SourceRoot -eq $projectRoot) { throw 'Use a clean managed validation worktree; preserve the development checkout.' }
$dirty=git -C $SourceRoot status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Validation source must start with no tracked modifications.' }
if (Test-Path -LiteralPath $BuildRoot) { throw 'Build output already exists; select a new directory.' }
New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null
$commit=(git -C $SourceRoot rev-parse HEAD).Trim()
$priorApp=$env:APPDATA; $priorLocal=$env:LOCALAPPDATA
$bus=Join-Path $SourceRoot 'default_bus_layout.tres'
$originalBus=[IO.File]::ReadAllBytes($bus)
function Invoke-Engine([string]$Label,[string[]]$Arguments) {
    $log=Join-Path $BuildRoot ($Label+'.txt')
    & $GodotPath @Arguments *> $log
    if ($LASTEXITCODE -ne 0) { throw "Godot $Label failed; see $log" }
    if ([IO.File]::ReadAllText($log) -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') { throw "Godot $Label reported errors; see $log" }
}
try {
    $env:APPDATA=Join-Path $projectRoot 'artifacts/godot-user'
    $env:LOCALAPPDATA=Join-Path $projectRoot 'artifacts/godot-local'
    Invoke-Engine 'import' @('--headless','--editor','--path',$SourceRoot,'--import','--quit')
    # This fresh, previously clean worktree is owned by this build. The editor
    # can normalize the audio bus; restore exactly the bytes captured above.
    $busNormalized=[Convert]::ToBase64String($originalBus) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($bus))
    if ($busNormalized) { [IO.File]::WriteAllBytes($bus,$originalBus) }
    $unexpected=@(git -c core.safecrlf=false -C $SourceRoot diff --name-only | Where-Object { $_ -notlike '*.import' })
    if ($unexpected.Count) { throw ('Unexpected source change after import: '+($unexpected -join ', ')) }
    $exported=[ordered]@{}
    foreach ($role in $Roles) {
        $folder=Join-Path $BuildRoot $role
        New-Item -ItemType Directory -Force $folder | Out-Null
        if ($CandidateFamily -eq 'Mine') {
            if ($role -eq 'qa-soak') { throw 'Mine has no endurance QA preset; do not reuse village endurance evidence.' }
            $preset=if ($role -eq 'candidate') { 'Windows Mine Candidate' } else { 'Windows Mine QA' }
        } else { $preset=switch ($role) { 'candidate' { 'Windows Blender Candidate' } 'qa' { 'Windows Blender QA' } 'qa-soak' { 'Windows Blender Soak QA' } } }
        Invoke-Engine ('export-'+$role) @('--headless','--path',$SourceRoot,'--export-release',$preset,(Join-Path $folder 'ProjectCrystal.exe'))
        foreach ($name in @('ASSET_CREDITS.md','GODOT_LICENSES.txt')) { Copy-Item -LiteralPath (Join-Path $SourceRoot ('docs/'+$name)) -Destination $folder }
        if ($role -eq 'candidate') {
            $launcher=if ($CandidateFamily -eq 'Mine') { 'tools/start_mine_reference.cmd' } else { 'tools/start_blender_village.cmd' }
            Copy-Item -LiteralPath (Join-Path $SourceRoot $launcher) -Destination $folder
        }
        Get-ChildItem -LiteralPath $folder -File | ForEach-Object { [pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'SHA256.json') -Encoding utf8
        $exported[$role.Replace('-','_')]=Join-Path $folder 'ProjectCrystal.exe'
    }
    $unexpected=@(git -c core.safecrlf=false -C $SourceRoot diff --name-only | Where-Object { $_ -notlike '*.import' })
    if ($unexpected.Count) { throw ('Export modified runtime source: '+($unexpected -join ', ')) }
    $receipt=[ordered]@{source_commit=$commit;source_root=$SourceRoot;candidate_family=$CandidateFamily;audio_bus_restored_to_original=$busNormalized;generated_import_metadata=@(git -c core.safecrlf=false -C $SourceRoot diff --name-only);engine=(& $GodotPath --version)}
    foreach ($key in $exported.Keys) { $receipt[$key]=$exported[$key] }
    $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $BuildRoot 'build_receipt.json') -Encoding utf8
    Write-Output ('BLENDER_WINDOWS_BUILD='+$BuildRoot)
}
finally { $env:APPDATA=$priorApp; $env:LOCALAPPDATA=$priorLocal }
