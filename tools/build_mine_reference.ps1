[CmdletBinding()]
param([string]$BlenderPath='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$script=Join-Path $root 'scripts/tools/build_mine_reference.py'
$log=Join-Path $root ('artifacts/mine-reference-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
& $BlenderPath --background --factory-startup --python-exit-code 1 --python $script *> $log
if ($LASTEXITCODE -ne 0) { throw "Blender failed; see $log" }
$text=Get-Content -LiteralPath $log -Raw
if ($text -match 'Traceback \(most recent call last\)' -or $text -notmatch 'MINE_MASTER_COMPLETE') { throw "Blender did not finish; see $log" }
$manifest=Get-Content -LiteralPath (Join-Path $root 'assets/models/mine_reference/manifest.json') -Raw | ConvertFrom-Json
if ($manifest.builder_sha256 -ne (Get-FileHash -LiteralPath $script).Hash.ToLower()) { throw 'Stale Blender manifest' }
& 'D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Scripts/python.exe' (Join-Path $root 'scripts/tools/write_mine_scene.py')
if ($LASTEXITCODE -ne 0) { throw 'Godot scene assembly failed' }
Write-Output "MINE_BUILD_LOG=$log"
