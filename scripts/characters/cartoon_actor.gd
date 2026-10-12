class_name CartoonActor
extends Node3D
## Presentation only: articulated mesh joints, independent of physics and combat state.
@export var model: PackedScene
@export var jelly: bool = false
var _model_root: Node3D
var _parts: Dictionary[StringName, Node3D] = {}
var _rest: Dictionary[StringName, Transform3D] = {}
var _phase: float = 0.0
var _motion: float = 0.0
var _dead: bool = false

func _ready() -> void:
	_model_root = model.instantiate() as Node3D
	add_child(_model_root)
	for part: StringName in [&"Head", &"Torso", &"ArmLeft", &"ArmRight", &"LegLeft", &"LegRight"]:
		var node: Node3D = _model_root.find_child(String(part), true, false) as Node3D
		if node != null:
			_parts[part] = node
			_rest[part] = node.transform

func set_motion(amount: float) -> void:
	_motion = clampf(amount, 0.0, 1.0)

func set_dead(value: bool) -> void:
	_dead = value
	if value:
		_model_root.scale = Vector3.ONE
		for part: StringName in _parts:
			_parts[part].transform = _rest[part]

func _process(delta: float) -> void:
	if _dead:
		return
	_phase += delta * lerpf(2.1, 10.0, _motion)
	if jelly:
		var pulse: float = sin(_phase) * 0.035
		_model_root.scale = Vector3(1.0 + pulse, 1.0 - pulse, 1.0 + pulse)
		return
	for part: StringName in _parts:
		var node: Node3D = _parts[part]
		node.transform = _rest[part]
		var swing: float = sin(_phase) * _motion * 0.5
		match part:
			&"LegLeft", &"ArmRight": node.rotate_object_local(Vector3.RIGHT, swing)
			&"LegRight", &"ArmLeft": node.rotate_object_local(Vector3.RIGHT, -swing)
			&"Torso": node.position.y += sin(_phase * 2.0) * 0.012
			&"Head": node.rotate_object_local(Vector3.UP, sin(_phase * 0.5) * 0.025)
