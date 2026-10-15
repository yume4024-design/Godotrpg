class_name ExplorationQuality
extends Node
## Session-only exploration presets. No gameplay/save state is owned here.
enum Preset { LOW, MEDIUM, HIGH }
signal preset_changed(preset: int)
var preset: Preset = Preset.HIGH
var _viewport: Viewport
var _sun: DirectionalLight3D

func setup(viewport: Viewport, sun: DirectionalLight3D) -> void:
	_viewport = viewport
	_sun = sun
	apply(Preset.HIGH)

func apply(value: int) -> bool:
	if value < Preset.LOW or value > Preset.HIGH or _viewport == null or _sun == null:
		return false
	preset = value as Preset
	_sun.shadow_enabled = preset != Preset.LOW
	_sun.directional_shadow_max_distance = 30.0 if preset == Preset.MEDIUM else 60.0
	_viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][preset]
	preset_changed.emit(preset)
	return true

func cycle() -> void:
	apply((preset + 1) % 3)

func label() -> String:
	return ["畫質：低", "畫質：中", "畫質：高"][preset]
