[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
    [string]$TemplateRoot = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$commit = (git -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source commit.' }
$committedSettings = (git -C $projectRoot show "$($commit):project.godot") -join "`n"
if ($LASTEXITCODE -ne 0 -or $committedSettings -notmatch '(?m)^config/version.prologue_candidate="(0\.6\.1-prologue-(rc\d+-\d{8}))"$') {
    throw 'Commit a valid prologue candidate version before packaging.'
}
$version = $Matches[1]
$buildId = $Matches[2]
$versionRoot = Join-Path $projectRoot ('builds/prologue-candidate/' + $buildId)
if (Test-Path -LiteralPath $versionRoot) { throw "Refusing to overwrite $versionRoot" }
if ([string]::IsNullOrWhiteSpace($TemplateRoot)) {
    $TemplateRoot = Join-Path $projectRoot 'artifacts/godot-user/Godot/export_templates/4.7.2.stable'
}
if ((Get-Content -LiteralPath (Join-Path $TemplateRoot 'version.txt') -Raw).Trim() -ne '4.7.2.stable') { throw 'Template version mismatch.' }
$runtime = Join-Path $TemplateRoot 'windows_release_x86_64.exe'
$engineVersion = (& $GodotPath --version | Out-String).Trim()
$templateVersion = (& $runtime --version | Out-String).Trim()
if ($engineVersion -ne '4.7.2.stable.official.ed1daf0bf' -or $templateVersion -ne $engineVersion) {
    throw 'Engine and release template must both be 4.7.2.stable.official.ed1daf0bf.'
}
$sourceRoot = Join-Path $versionRoot 'source'
$profile = Join-Path $versionRoot 'build-profile'
$tempRoot = Join-Path $versionRoot 'build-temp'
$logs = Join-Path $versionRoot 'logs'
New-Item -ItemType Directory -Path $sourceRoot,$profile,$tempRoot,$logs -Force | Out-Null
$isolatedTemplates = Join-Path $profile 'Godot/export_templates/4.7.2.stable'
New-Item -ItemType Directory -Path $isolatedTemplates -Force | Out-Null
foreach ($name in @('version.txt','windows_release_x86_64.exe','windows_debug_x86_64.exe','icudt_godot.dat')) {
    Copy-Item -LiteralPath (Join-Path $TemplateRoot $name) -Destination $isolatedTemplates
}
# Export only a Git snapshot. Untracked art experiments and local modifications
# never silently become part of a package labelled with a commit SHA.
$archive = Join-Path $versionRoot 'source.zip'
git -C $projectRoot archive --format=zip --output=$archive $commit project.godot default_bus_layout.tres export_presets.cfg assets scenes scripts data tests tools docs/ASSET_CREDITS.md docs/GODOT_LICENSES.txt
if ($LASTEXITCODE -ne 0) { throw 'Git source snapshot failed.' }
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'default_bus_layout.tres'))) {
    throw 'The committed runtime snapshot must include the Music/SFX audio buses.'
}
if (-not (Select-String -LiteralPath (Join-Path $sourceRoot 'project.godot') -SimpleMatch $version -Quiet)) {
    throw 'Committed candidate version is missing from the build snapshot.'
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
    $executable = Join-Path $destination 'ProjectCrystal.exe'
    Invoke-BuildGodot "export-$role" @('--export-release',$preset,$executable)
    $manifest = [ordered]@{
        version=$version; role=$role; source_commit=$commit
        source_branch=(git -C $projectRoot branch --show-current).Trim()
        source_kind='git archive (tracked committed files only)'
        engine='4.7.2.stable.official.ed1daf0bf'
        runtime_origin='Godot --export-release with matching Windows x86_64 release template'
        template_sha256=(Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash.ToLowerInvariant()
        entry_scene=$(if ($role -eq 'candidate') { 'res://scenes/main/prologue_candidate.tscn' } else { 'res://tests/qa_entry.tscn' })
        game_scene='res://scenes/main/prologue_candidate.tscn'
        save_slot=$(if ($role -eq 'candidate') { 'user://crystal_prologue_candidate_20261027_slot_01.json' } else { 'user://mine_reference_tests/story_visual.json' })
        executable_sha256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
        pck_sha256=(Get-FileHash -LiteralPath $pck -Algorithm SHA256).Hash.ToLowerInvariant()
        acceptance='Pending package tests; manual acceptance paused'
    }
    if ($role -eq 'candidate') {
        foreach ($notice in @('ASSET_CREDITS.md','GODOT_LICENSES.txt')) {
            $sourceNotice = Join-Path (Join-Path $sourceRoot 'docs') $notice
            if (-not (Test-Path -LiteralPath $sourceNotice -PathType Leaf)) { throw "Missing committed notice: $notice" }
            Copy-Item -LiteralPath $sourceNotice -Destination (Join-Path $destination $notice)
        }
        $manifest.asset_credits_sha256 = (Get-FileHash -LiteralPath (Join-Path $destination 'ASSET_CREDITS.md') -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest.godot_notices_sha256 = (Get-FileHash -LiteralPath (Join-Path $destination 'GODOT_LICENSES.txt') -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'manifest.json') -Encoding utf8
}
$candidate = Join-Path $versionRoot 'candidate'
Copy-Item -LiteralPath (Join-Path $sourceRoot 'tools/start_prologue_candidate.cmd') -Destination $candidate
@"
失落星核 — Windows 序章候選 $version
啟動：start_prologue_candidate.cmd
移動：WASD／方向鍵／左搖桿；跑步：Shift／LB；互動：E／A；手冊：M／Menu。
流程：旅館 → 公會 → 莉雅入隊 → 低語森林教學戰 → 礦坑古代星晶／Boss → 回公會交付。
點擊小地圖或在手冊選「地圖」可查看完整道路與地標；沒有快速傳送。
本包使用獨立 user_test 存檔；不覆蓋正式 v0.6.1 或舊候選包。
舊候選檔如需遷移，先備份，再複製至本包 user_test 中相同相對位置。首次載入只在記憶體升級；明確保存後保留 .bak。
以 manifest 的 source_commit 為準；人工美術與實體輸入驗收維持暫停。
"@ | Set-Content -LiteralPath (Join-Path $candidate 'README.txt') -Encoding utf8
Write-Output "PROLOGUE_PACKAGE_PATH=$candidate"
Write-Output "PROLOGUE_SOURCE_COMMIT=$commit"
