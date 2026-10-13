class_name StorySequence
extends Node
## Finite visible sequences. EventRunner commits only after the animation ends.
var crystal: Node3D
var crystal_light: OmniLight3D
var active: bool = false
var _overlay: CanvasLayer
var _card: Label

func _ready() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 6
	add_child(_overlay)
	var shade: ColorRect = ColorRect.new()
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.06, 0.09, 0.6)
	_card = Label.new()
	shade.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	_card.add_theme_font_override("font", font)
	_card.add_theme_font_size_override("font_size", 30)
	_card.add_theme_color_override("font_color", Color("#ebd39c"))
	_overlay.hide()

func bind_map(map: ExplorationMap) -> void:
	crystal = map.sequence_target
	crystal_light = map.sequence_light

func can_play(id: StringName) -> bool:
	return (id == &"crystal_awakening" and is_instance_valid(crystal) and is_instance_valid(crystal_light)) or id == &"village_departure"

func play(id: StringName) -> bool:
	if active or not can_play(id): return false
	active = true
	if id == &"crystal_awakening":
		var original: Vector3 = crystal.scale
		var energy: float = crystal_light.light_energy
		var tween: Tween = create_tween()
		for pulse: int in range(3):
			tween.tween_property(crystal, "scale", original * (1.15 + pulse * 0.05), 0.45).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(crystal_light, "light_energy", 4.0 + pulse, 0.45)
			tween.tween_property(crystal, "scale", original, 0.45).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(crystal_light, "light_energy", energy, 0.45)
		await tween.finished
	else:
		_card.text = "序章完成  ·  灰石村的異變\n\n第一章  ·  翠影森林的守護者\n\n新的旅程，即將展開……"
		_overlay.show()
		_card.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_card, "modulate:a", 1.0, 0.8)
		tween.tween_interval(1.7)
		tween.tween_property(_card, "modulate:a", 0.0, 0.8)
		await tween.finished
		_overlay.hide()
	active = false
	return true
