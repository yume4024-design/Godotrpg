extends "res://scripts/characters/user_hero_actor.gd"
## Presentation follows resolved actions; it never changes combat state.
var battle_pose: StringName = &""
var _pose_time: float = 0.0
const POSE_SECONDS: float = 0.65

func play_battle_action(action: StringName) -> void:
	if _dead: return
	battle_pose = action
	_pose_time = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if _dead or skeleton == null or battle_pose == &"": return
	_pose_time += delta
	if _pose_time >= POSE_SECONDS:
		battle_pose = &""
		return
	var weight: float = sin(PI * _pose_time / POSE_SECONDS)
	match battle_pose:
		&"mend", &"star_spark":
			_offset("ArmLeft", Vector3(-0.28, 0, 0.12) * weight)
			_offset("ArmRight", Vector3(-0.28, 0, -0.12) * weight)
			_offset("Head", Vector3(-0.04, 0, 0) * weight)
		&"attack":
			_offset("ArmRight", Vector3(-0.38, 0.1, 0) * weight)
			_offset("Torso", Vector3(0, 0.06, 0) * weight)
		&"guard":
			_offset("ArmLeft", Vector3(-0.2, 0, 0.08) * weight)
			_offset("ArmRight", Vector3(-0.2, 0, -0.08) * weight)
		&"potion":
			_offset("ArmLeft", Vector3(-0.3, 0, 0) * weight)
		&"hit":
			_offset("Torso", Vector3(-0.09, 0, 0) * weight)
			_offset("Head", Vector3(0.06, 0, 0) * weight)

func _offset(bone_name: String, angles: Vector3) -> void:
	var index: int = skeleton.find_bone(bone_name)
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * Quaternion.from_euler(angles))

func set_dead(value: bool) -> void:
	if value: battle_pose = &""
	super.set_dead(value)
