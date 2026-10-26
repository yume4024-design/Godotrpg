[CmdletBinding()]
param([string]$GodotPath = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$commit = (git -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' }
$version = '0.6.1-prologue-rc2-20261027'
$committedSettings = git -C $projectRoot show "$($commit):project.godot"
if ($LASTEXITCODE -ne 0 -or -not ($committedSettings -match [regex]::Escape($version))) {
    throw 'Commit the RC2 configuration before packaging.'
}
$versionRoot = Join-Path $projectRoot 'builds/prologue-candidate/rc2-20261027'
if (Test-Path -LiteralPath $versionRoot) { throw "Refusing to overwrite $versionRoot" }
$runtime = Join-Path $projectRoot 'builds/mine-reference/rc2-ef0764c/candidate/ProjectCrystal.exe'
if ((Get-Item -LiteralPath $runtime).VersionInfo.FileVersion -ne '4.7.2') { throw 'Runtime version mismatch.' }
$sourceRoot = Join-Path $versionRoot 'source'
$profile = Join-Path $versionRoot 'build-profile'
$tempRoot = Join-Path $versionRoot 'build-temp'
$logs = Join-Path $versionRoot 'logs'
New-Item -ItemType Directory -Path $sourceRoot,$profile,$tempRoot,$logs -Force | Out-Null
# Export only a Git snapshot. Untracked art experiments and local modifications
# never silently become part of a package labelled with a commit SHA.
$archive = Join-Path $versionRoot 'source.zip'
git -C $projectRoot archive --format=zip --output=$archive $commit project.godot export_presets.cfg assets scenes scripts data tests tools
if ($LASTEXITCODE -ne 0) { throw 'Git source snapshot failed.' }
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
if (-not (Select-String -LiteralPath (Join-Path $sourceRoot 'project.godot') -SimpleMatch $version -Quiet)) {
    throw 'Commit the RC2 configuration before packaging.'
}

function Invoke-BuildGodot([string]$Name, [string[]]$EngineArguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $GodotPath
    $info.Arguments = (@('--headless','--path',$sourceRoot,'--log-file',(Join-Path $logs "$Name.log")) + $EngineArguments | ForEach-Object { '"{0}"' -f $_ }) -join ' '
    $info.WorkingDirectory = $sourceRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['APPDATA'] = $profile
    $info.EnvironmentVariables['LOCALAPPDATA'] = $profile
    $info.EnvironmentVariables['TEMP'] = $tempRoot
    $info.EnvironmentVariables['TMP'] = $tempRoot
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw "$Name did not start." }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(600000)) { $process.Kill(); throw "$Name timed out. Inspect its log before retrying." }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
            $output | Set-Content -LiteralPath (Join-Path $logs "$Name-output.txt") -Encoding utf8
            throw "$Name failed; see $logs"
        }
        Write-Output "PACKAGE_STEP=$Name PASS"
    } finally { $process.Dispose() }
}

Invoke-BuildGodot 'import' @('--import')
foreach ($role in @('candidate','qa')) {
    $destination = Join-Path $versionRoot $role
    New-Item -ItemType Directory -Path $destination | Out-Null
    $preset = if ($role -eq 'candidate') { 'Windows Prologue Candidate' } else { 'Windows Prologue QA' }
    $pck = Join-Path $destination 'ProjectCrystal.pck'
    Invoke-BuildGodot "export-$role" @('--export-pack',$preset,$pck)
    Copy-Item -LiteralPath $runtime -Destination (Join-Path $destination 'ProjectCrystal.exe')
    $manifest = [ordered]@{
        version=$version; role=$role; source_commit=$commit
        source_branch=(git -C $projectRoot branch --show-current).Trim()
        source_kind='git archive (tracked committed files only)'
        engine='4.7.2.stable.official.ed1daf0bf'
        runtime_origin='Existing verified Godot 4.7.2 runtime; not rebuilt from export templates'
        entry_scene='res://scenes/main/prologue_candidate.tscn'
        save_slot='user://crystal_prologue_candidate_20261027_slot_01.json'
        executable_sha256=(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash.ToLowerInvariant()
        pck_sha256=(Get-FileHash -LiteralPath $pck -Algorithm SHA256).Hash.ToLowerInvariant()
        acceptance='Pending package tests; manual acceptance paused'
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'manifest.json') -Encoding utf8
}
$candidate = Join-Path $versionRoot 'candidate'
Copy-Item -LiteralPath (Join-Path $sourceRoot 'tools/start_prologue_candidate.cmd') -Destination $candidate
@'
失落星核 — Windows 序章候選 RC2
啟動：start_prologue_candidate.cmd
移動：WASD／方向鍵／左搖桿；跑步：Shift／LB；互動：E／A；手冊：M／Menu。
流程：旅館 → 公會 → 莉雅入隊 → 低語森林教學戰 → 礦坑古代星晶／Boss → 回公會交付。
本包使用獨立 user_test 存檔；不覆蓋正式 v0.6.1 或 RC1。
舊候選檔如需遷移，先備份，再複製至本包 user_test 中相同相對位置。首次載入只在記憶體升級；明確保存後保留 .bak。
以 manifest 的 source_commit 為準；人工美術與實體輸入驗收維持暫停。
'@ | Set-Content -LiteralPath (Join-Path $candidate 'README.txt') -Encoding utf8
Write-Output "PROLOGUE_PACKAGE_PATH=$candidate"
Write-Output "PROLOGUE_SOURCE_COMMIT=$commit"
