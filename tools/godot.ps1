[CmdletBinding()]
param(
    [ValidateSet("PreviewRenRuntime","VisualRenMovement","VisualRenStory","TestRenStoryReload","VisualRenRuntime","VisualRenAuthored","VisualNPCIntegration",'TestExplorationLocomotion', 'ExportEnemyAssetQA', 'ProfileEnemyAssets', 'TestEnemyController', 'VisualEnemyController', 'TestBattleNameplates', 'VisualBattleNameplates', 'TestAssetBudget', 'ExportG083QA', 'TestG08Routes', 'TestG08Accessibility', 'ExportG08Candidate', 'ExportG08QA', 'TestPixalAttachments', 'TestWindowsStability', 'TestPixalCharacters', 'TestCharacterSteps', 'TestLiaVillageInn', 'TestLiaVillageFarm', 'TestLiaVillageMine', 'TestFemalePlatform', 'TestFemaleSlope25', 'TestFemaleRamp25', 'TestFemaleFootBoundary', 'ProfileLiaFootPlacement', 'ExportGreystonePreview', 'TestFemaleRamp30', 'TestFemaleRamp120', 'TestFemaleRampTransitions', 'TestFemaleSlopeMovement', 'TestFemaleSlope', 'TestCharacterLifecycle', 'TestFemaleMotionBoundary', 'ExportCharacterQA', 'ProfileCharacters', 'PreviewLiaMovement', 'TestLiaMovement', 'VisualFemaleHand', 'PreviewCharacters', 'TestCharacterPreview', 'VisualFemaleFace', 'TestFemaleGrounding', 'VisualFemaleAnimation', 'PreviewFemale', 'PreviewUserHero', 'ProfileGreystoneEndurance', 'ProfileGreystoneDynamic', 'VisualActionEffects', 'PrepareWildernessRestart', 'TestForestRestart', 'TestMineRestart', 'TestWildernessEndurance', 'TestWildernessBalance', 'VisualExpansion', 'VisualGreystoneQuality', 'PrepareGreystoneMaterials', 'ProfileGreystone', 'TestEnemyAI', 'TestG06TouchCommerce', 'VisualG06TouchCommerce', 'TestG06Touch', 'VisualG06Touch', 'TestG06Commerce', 'VisualG06Commerce', 'TestG06CommerceReload', 'TestG06Story', 'VisualG06Story', 'TestG06StoryReload', 'VisualG06NPC', 'TestG06NPC', 'TestG06', 'VisualG06', 'TestG06Reload', 'RunG06', 'VisualGreystoneProps', 'TestGreystoneProps', 'TestGreystoneBuildings', 'VisualGreystoneBuildings', 'TestGreystone', 'VisualGreystone', 'PreviewGreystone', 'TestVillage', 'VisualVillage', 'Version', 'Check', 'Smoke', 'Test', 'TestPhase2', 'VisualPhase2', 'TestPhase3', 'VisualPhase3', 'PreviewBattle', 'TestPhase4', 'VisualPhase4', 'TestPhase5', 'VisualPhase5', 'TestPhase5Reload', 'TestPhase6', 'VisualPhase6', 'ExportWindows', 'ExportQA', 'ControllerProbe', 'TestArt', 'VisualArt', 'PreviewArt', 'Editor', 'Run')]
    [string]$Mode = 'Version',
    [string]$GodotPath = $env:GODOT_PATH,
    [ValidateSet("spore_sprite","ore_beetle","thorn_boar","corrupted_guardian","crystal_bat")]
    [string]$Asset = "spore_sprite",
    [string]$ReviewModel = '',
    [switch]$Describe
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Pass -GodotPath with an executable file."
}
if ($Mode -ne 'Version' -and -not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot') -PathType Leaf)) {
    throw 'project.godot is not present. Implement Phase 1 before checking or running the game.'
}

$profileRoot = Join-Path $projectRoot 'artifacts\godot-user'
$cacheRoot = Join-Path $projectRoot 'artifacts\godot-local'
$tempRoot = Join-Path $projectRoot 'artifacts\godot-tmp'
New-Item -ItemType Directory -Path $profileRoot, $cacheRoot, $tempRoot -Force | Out-Null

$engineArgs = @('--version')
if ($Mode -ne 'Version') {
    $logRoot = Join-Path $projectRoot 'artifacts\logs'
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $logPath = Join-Path $logRoot ('{0}-{1}.log' -f $Mode.ToLowerInvariant(), (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    $engineArgs = @('--path', $projectRoot, '--log-file', $logPath)
    if ($Mode -in @('ExportEnemyAssetQA', 'TestEnemyController', 'TestBattleNameplates', 'TestAssetBudget', 'ExportG083QA', 'ExportG08Candidate', 'ExportG08QA', 'PrepareWildernessRestart', 'TestForestRestart', 'TestMineRestart', 'TestWildernessEndurance', 'TestWildernessBalance', 'PrepareGreystoneMaterials', 'TestEnemyAI', 'TestG06TouchCommerce', 'TestG06Touch', 'TestG06Commerce', 'TestG06CommerceReload', 'TestG06Story', 'TestG06StoryReload', 'TestG06NPC', 'TestG06', 'TestG06Reload', 'TestGreystoneProps', 'TestGreystoneBuildings', 'TestGreystone', 'TestVillage', 'TestFemaleMotionBoundary', 'ExportCharacterQA', 'ExportGreystonePreview', 'Check', 'Smoke', 'Test', 'TestPhase2', 'TestPhase3', 'TestArt', 'TestPhase4', 'TestPhase5', 'TestPhase5Reload', 'TestPhase6', 'ExportWindows', 'ExportQA')) { $engineArgs += '--headless' }

    if ($Mode -in @('ExportG083QA','ExportG08Candidate','ExportG08QA')) {
        $role = if ($Mode -eq 'ExportG083QA') { 'qa-soak' } elseif ($Mode -eq 'ExportG08Candidate') { 'candidate' } else { 'qa' }
        $preset = if ($Mode -eq 'ExportG083QA') { 'Windows G083 Soak QA' } elseif ($Mode -eq 'ExportG08Candidate') { 'Windows G08 Candidate' } else { 'Windows G08 QA' }
        $candidateRoot = Join-Path $projectRoot ('builds/g08/' + $role + '/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Path $candidateRoot -Force | Out-Null
        $candidateExe = Join-Path $candidateRoot 'ProjectCrystal.exe'
        $engineArgs += @('--export-release', $preset, $candidateExe)
        Write-Output "G08_EXPORT_PATH=$candidateExe"
    }
    if ($Mode -eq 'ExportEnemyAssetQA') {
        $assetFolder = Join-Path $projectRoot ('builds/asset-qa/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force $assetFolder | Out-Null
        $assetExe = Join-Path $assetFolder 'ProjectCrystal.exe'
        $engineArgs += @('--export-release','Windows A04 Enemy QA',$assetExe)
        Write-Output "A04_EXPORT_PATH=$assetExe"
    }
    if ($Mode -eq 'ProfileEnemyAssets') { $engineArgs += @('--script','res://tests/enemy_asset_performance_test.gd') }
    if ($Mode -eq 'ExportGreystonePreview') {
        $previewBuildRoot = Join-Path $projectRoot ('builds/greystone-preview/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Path $previewBuildRoot -Force | Out-Null
        $engineArgs += @('--export-release', 'Windows Greystone Preview', (Join-Path $previewBuildRoot 'ProjectCrystal.exe'))
    }
    if ($Mode -eq 'ExportCharacterQA') {
        $characterBuildRoot = Join-Path $projectRoot ('builds/character-qa/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Path $characterBuildRoot -Force | Out-Null
        $engineArgs += @('--export-release', 'Windows Character QA', (Join-Path $characterBuildRoot 'ProjectCrystal.exe'))
    }
    if ($Mode -in @('ExportWindows', 'ExportQA')) {
        $buildFolder = if ($Mode -eq 'ExportWindows') { 'windows' } else { 'qa' }
        $presetName = if ($Mode -eq 'ExportWindows') { 'Windows Desktop' } else { 'Windows QA' }
        $buildRoot = Join-Path $projectRoot ('builds/' + $buildFolder)
        New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
        $engineArgs += @('--export-release', $presetName, (Join-Path $buildRoot 'ProjectCrystal.exe'))
    }
    if ($Mode -in @('TestGreystone', 'VisualGreystone')) { $engineArgs += @('--script', 'res://tests/greystone_layout_test.gd') }
    if ($Mode -in @('TestGreystoneBuildings', 'VisualGreystoneBuildings')) { $engineArgs += @('--script', 'res://tests/greystone_buildings_test.gd') }
    if ($Mode -in @('VisualGreystoneProps', 'TestGreystoneProps')) { $engineArgs += @('--script', 'res://tests/greystone_props_test.gd') }
    if ($Mode -in @('TestEnemyController','VisualEnemyController')) { $engineArgs += @('--script','res://tests/rigged_enemy_controller_test.gd') }
    if ($Mode -in @('TestBattleNameplates','VisualBattleNameplates')) { $engineArgs += @('--script','res://tests/battle_nameplate_test.gd') }
    if ($Mode -in @('TestG06','VisualG06','TestG06Reload')) { $engineArgs += @('--script','res://tests/greystone_integration_test.gd') }
    if ($Mode -eq 'TestG06Reload') { $engineArgs += @('--','--reload') }
    if ($Mode -in @('VisualG06NPC','TestG06NPC')) { $engineArgs += @('--script','res://tests/greystone_npc_test.gd') }
    if ($Mode -eq 'VisualNPCIntegration') { $engineArgs += @('--script','res://tests/npc_integration_test.gd') }
    if ($Mode -eq 'PreviewRenRuntime') { $engineArgs += 'res://scenes/tools/ren_runtime_game.tscn' }
    if ($Mode -eq 'VisualRenMovement') { $engineArgs += @('--script','res://tests/ren_runtime_movement_test.gd') }
    if ($Mode -in @('VisualRenStory','TestRenStoryReload')) { $engineArgs += @('--script','res://tests/ren_runtime_story_test.gd') }
    if ($Mode -eq 'TestRenStoryReload') { $engineArgs += @('--','--reload') }
    if ($Mode -eq 'VisualRenRuntime') { $engineArgs += @('--script','res://tests/ren_runtime_test.gd') }
    if ($Mode -eq 'VisualRenAuthored') {
        $engineArgs += @('--script','res://tests/ren_authored_review.gd')
        if ($ReviewModel) { $engineArgs += @('--', ('--model=' + $ReviewModel)) }
    }
    if ($Mode -in @('TestG06Story','VisualG06Story','TestG06StoryReload')) { $engineArgs += @('--script','res://tests/greystone_story_test.gd') }
    if ($Mode -eq 'TestG06StoryReload') { $engineArgs += @('--','--reload') }
    if ($Mode -in @('TestG06Commerce','VisualG06Commerce','TestG06CommerceReload')) { $engineArgs += @('--script','res://tests/greystone_commerce_test.gd') }
    if ($Mode -eq 'TestG06CommerceReload') { $engineArgs += @('--','--reload') }
    if ($Mode -in @('TestG06Touch','VisualG06Touch')) { $engineArgs += @('--script','res://tests/greystone_touch_test.gd') }
    if ($Mode -in @('TestG06TouchCommerce','VisualG06TouchCommerce')) { $engineArgs += @('--script','res://tests/greystone_touch_commerce_test.gd') }
    if ($Mode -eq 'TestG08Routes') { $engineArgs += @('--script','res://tests/greystone_layout_test.gd','--','--bounded-stairs') }
    if ($Mode -eq 'TestG08Accessibility') { $engineArgs += @('--script','res://tests/g08_accessibility_test.gd') }
    if ($Mode -eq 'TestEnemyAI') { $engineArgs += @('--script','res://tests/enemy_targeting_test.gd') }
    if ($Mode -eq 'PrepareGreystoneMaterials') { $engineArgs += @('--script','res://scripts/tools/greystone/share_terrain_materials.gd') }
    if ($Mode -in @('PrepareWildernessRestart', 'TestForestRestart', 'TestMineRestart')) {
        $restartFlag = switch ($Mode) { 'PrepareWildernessRestart' { '--prepare' }; 'TestForestRestart' { '--forest' }; 'TestMineRestart' { '--mine' } }
        $engineArgs += @('--script','res://tests/wilderness_restart_test.gd','--',$restartFlag)
    }
    if ($Mode -eq 'TestWildernessEndurance') { $engineArgs += @('--script','res://tests/wilderness_endurance_test.gd') }
    if ($Mode -eq 'TestWildernessBalance') { $engineArgs += @('--script','res://tests/wilderness_balance_test.gd') }
    if ($Mode -eq 'PreviewLiaMovement') { $engineArgs += @('res://scenes/tools/lia_movement_preview.tscn') }
    if ($Mode -eq 'TestLiaMovement') { $engineArgs += @('--script','res://tests/lia_movement_test.gd') }
    if ($Mode -eq 'VisualFemaleHand') { $engineArgs += @('--script','res://tests/female_hand_test.gd') }
    if ($Mode -eq 'PreviewCharacters') { $engineArgs += @('res://scenes/tools/character_preview.tscn') }
    if ($Mode -eq 'TestCharacterPreview') { $engineArgs += @('--script','res://tests/character_preview_test.gd') }
    if ($Mode -eq 'VisualFemaleFace') { $engineArgs += @('--script','res://tests/female_face_test.gd') }
    if ($Mode -eq 'TestFemaleGrounding') { $engineArgs += @('--script','res://tests/female_grounding_test.gd') }
    if ($Mode -eq 'TestPixalAttachments') { $engineArgs += @('--script','res://tests/female_battle_animation_test.gd','--','--pixal') }
    if ($Mode -eq 'VisualFemaleAnimation') { $engineArgs += @('--script','res://tests/female_battle_animation_test.gd') }
    if ($Mode -eq 'PreviewFemale') { $engineArgs += @('--script','res://tests/female_character_preview.gd') }
    if ($Mode -eq 'PreviewUserHero') { $engineArgs += @('--script','res://tests/user_hero_preview.gd') }
    if ($Mode -eq 'VisualActionEffects') { $engineArgs += @('--script','res://tests/action_effect_test.gd') }
    if ($Mode -eq 'VisualExpansion') { $engineArgs += @('--script','res://tests/wilderness_expansion_test.gd') }
    if ($Mode -eq 'VisualGreystoneQuality') { $engineArgs += @('--script','res://tests/greystone_quality_test.gd') }
    if ($Mode -eq 'TestFemaleRamp30') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd','--','--transitions','--test-fps=30') }
    if ($Mode -eq 'TestFemaleRamp120') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd','--','--transitions','--test-fps=120') }
    if ($Mode -eq 'TestFemaleRampTransitions') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd','--','--transitions') }
    if ($Mode -eq 'TestFemaleSlopeMovement') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd') }
    if ($Mode -eq 'TestFemaleSlope') { $engineArgs += @('--script','res://tests/female_slope_test.gd') }
    if ($Mode -eq 'TestCharacterLifecycle') { $engineArgs += @('--script','res://tests/character_lifecycle_test.gd') }
    if ($Mode -eq 'TestFemaleMotionBoundary') { $engineArgs += @('--script','res://tests/female_motion_boundary_test.gd') }
    if ($Mode -in @('TestLiaVillageInn','TestLiaVillageFarm','TestLiaVillageMine')) {
        $routeSite = switch ($Mode) { 'TestLiaVillageInn' {'inn'} 'TestLiaVillageFarm' {'farm'} 'TestLiaVillageMine' {'mine'} }
        $engineArgs += @('--script','res://tests/lia_village_route_test.gd','--', ('--site=' + $routeSite))
    }
    if ($Mode -eq 'TestFemalePlatform') { $engineArgs += @('--script','res://tests/female_platform_test.gd') }
    if ($Mode -eq 'TestFemaleSlope25') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd','--','--slope-degrees=25') }
    if ($Mode -eq 'TestFemaleRamp25') { $engineArgs += @('--script','res://tests/female_slope_movement_test.gd','--','--transitions','--slope-degrees=25') }
    if ($Mode -eq 'TestAssetBudget') { $engineArgs += @('--script','res://tests/asset_budget_test.gd') }
    if ($Mode -eq 'TestPixalCharacters') { $engineArgs += @('--script','res://tests/pixal_character_test.gd') }
    if ($Mode -eq 'TestExplorationLocomotion') { $engineArgs += @('--script','res://tests/exploration_locomotion_test.gd') }
    if ($Mode -eq 'TestCharacterSteps') { $engineArgs += @('--script','res://tests/character_step_acceptance.gd') }
    if ($Mode -eq 'TestFemaleFootBoundary') { $engineArgs += @('--script','res://tests/female_foot_boundary_test.gd') }
    if ($Mode -eq 'ProfileLiaFootPlacement') { $engineArgs += @('--script','res://tests/lia_foot_performance_probe.gd') }
    if ($Mode -eq 'ProfileCharacters') { $engineArgs += @('--script','res://tests/character_performance_probe.gd') }
    if ($Mode -eq 'ProfileGreystoneEndurance') { $engineArgs += @('--script','res://tests/greystone_endurance_probe.gd') }
    if ($Mode -eq 'ProfileGreystoneDynamic') { $engineArgs += @('--script','res://tests/greystone_dynamic_probe.gd') }
    if ($Mode -eq 'ProfileGreystone') { $engineArgs += @('--script','res://tests/greystone_performance_probe.gd') }
    if ($Mode -eq 'RunG06') { $engineArgs += 'res://scenes/main/greystone_integration.tscn' }
    if ($Mode -eq 'PreviewGreystone') { $engineArgs += 'res://scenes/world/greystone_preview.tscn' }
    if ($Mode -eq 'TestWindowsStability') { $engineArgs += @('--script','res://tests/windows_stability_test.gd') }
    if ($Mode -eq 'Check') { $engineArgs += '--import' }
    if ($Mode -eq 'Smoke') { $engineArgs += @('--quit-after', '120') }
    if ($Mode -eq 'Test') { $engineArgs += @('--script', 'res://tests/phase1_movement_test.gd') }
    if ($Mode -in @('TestPhase2', 'VisualPhase2')) { $engineArgs += @('--script', 'res://tests/phase2_exploration_test.gd') }
    if ($Mode -in @('TestPhase3', 'VisualPhase3', 'PreviewBattle')) { $engineArgs += @('--script', 'res://tests/phase3_battle_test.gd') }
    if ($Mode -in @('TestPhase4', 'VisualPhase4')) { $engineArgs += @('--script', 'res://tests/phase4_progression_test.gd') }
    if ($Mode -in @('TestPhase5', 'VisualPhase5', 'TestPhase5Reload')) { $engineArgs += @('--script', 'res://tests/phase5_prologue_test.gd') }
    if ($Mode -in @('TestPhase6', 'VisualPhase6')) { $engineArgs += @('--script', 'res://tests/phase6_delivery_test.gd') }
    if ($Mode -eq 'TestPhase5Reload') { $engineArgs += @('--', '--reload') }
    if ($Mode -in @('TestVillage', 'VisualVillage')) { $engineArgs += @('--script', 'res://tests/village_art_test.gd') }
    if ($Mode -eq 'ControllerProbe') { $engineArgs += @('--script', 'res://tests/controller_probe.gd') }
    if ($Mode -eq 'PreviewBattle') { $engineArgs += @('--', '--manual') }
    if ($Mode -in @('TestArt', 'VisualArt', 'PreviewArt')) { $engineArgs += @('--script', 'res://tests/cartoon_asset_test.gd') }
    if ($Mode -eq 'PreviewArt') { $engineArgs += @('--', '--manual') }
    if ($Mode -in @('TestEnemyController','VisualEnemyController','ProfileEnemyAssets')) { $engineArgs += @('--', ('--asset=' + $Asset)) }
    if ($Mode -eq 'Editor') { $engineArgs += '--editor' }
}

if ($Describe) {
    [ordered]@{mode=$Mode;engine=$GodotPath;arguments=$engineArgs;project=$projectRoot} | ConvertTo-Json -Depth 5 | Write-Output
    return
}

# Quote each argument independently for Windows PowerShell and PowerShell 7.
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $GodotPath
$startInfo.Arguments = ($engineArgs | ForEach-Object { '"{0}"' -f $_ }) -join ' '
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.EnvironmentVariables['APPDATA'] = $profileRoot
$startInfo.EnvironmentVariables['LOCALAPPDATA'] = $cacheRoot
$startInfo.EnvironmentVariables['TEMP'] = $tempRoot
$startInfo.EnvironmentVariables['TMP'] = $tempRoot
if ($Mode -in @('PreviewRenRuntime', 'PreviewLiaMovement', 'PreviewCharacters', 'RunG06', 'PreviewGreystone', 'Editor', 'Run', 'PreviewBattle', 'PreviewArt', 'ControllerProbe')) {
    # Use the graphical binary for detached windows. The console wrapper inherits
    # the caller's pipe handles and can stall after a short-lived tool shell exits.
    $graphicalPath = $GodotPath -replace '_console\.exe$', '.exe'
    if (Test-Path -LiteralPath $graphicalPath -PathType Leaf) {
        $startInfo.FileName = $graphicalPath
    }
    $launched = [System.Diagnostics.Process]::Start($startInfo)
    Write-Output "Started $Mode (PID $($launched.Id)). Log: $logPath"
    $launched.Dispose()
    return
}
if ($Mode -eq 'TestWindowsStability') {
    $graphicalPath = $GodotPath -replace '_console\.exe$', '.exe'
    if (-not (Test-Path -LiteralPath $graphicalPath)) { throw 'Graphical Godot binary required for process memory sampling.' }
    $startInfo.FileName = $graphicalPath
}
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
try {
    if (-not $process.Start()) { throw 'Godot process did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutMs = if ($Mode -eq 'TestWindowsStability') { 1950000 } elseif ($Mode -in @('VisualRenMovement','VisualRenStory','ProfileGreystoneEndurance','TestExplorationLocomotion')) { 180000 } elseif ($Mode -in @('TestLiaVillageFarm','TestLiaVillageMine','TestG06NPC')) { 120000 } else { 60000 }
    if ($Mode -eq 'TestWindowsStability') {
        $rssPath = Join-Path $projectRoot 'artifacts/performance/g075-process.csv'
        'elapsed_seconds,working_set_bytes,private_bytes,peak_working_set_bytes' | Set-Content $rssPath
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(1000) -and $clock.ElapsedMilliseconds -lt $timeoutMs) {
            $process.Refresh()
            if (-not $process.HasExited) {
                ('{0:F3},{1},{2},{3}' -f $clock.Elapsed.TotalSeconds,$process.WorkingSet64,$process.PrivateMemorySize64,$process.PeakWorkingSet64) | Add-Content $rssPath
            }
        }
    }
    if (-not $process.WaitForExit([Math]::Max(1, $(if ($Mode -eq 'TestWindowsStability') { 1 } else { $timeoutMs })))) {
        $process.Kill()
        throw "Godot exceeded the $timeoutMs ms timeout. Inspect the log before retrying."
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $output = $stdout + [Environment]::NewLine + $stderr
    Write-Output $output.Trim()
    if ($process.ExitCode -ne 0) { throw "Godot exited with code $($process.ExitCode)." }
    if ($output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|Failed loading resource)') {
        throw 'Godot reported an error despite its exit code. Inspect the output and log.'
    }
    if ($Mode -ne 'Version') { Write-Output "Log: $logPath" }
} finally {
    $process.Dispose()
}
