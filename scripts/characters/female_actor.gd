extends "res://scripts/characters/user_hero_actor.gd"
## Imported clips own the skeleton during battle; idle resumes after explicit reset.
var battle_pose: StringName = &""
var animation_player: AnimationPlayer
var _clip_rest: Dictionary[int, Quaternion] = {}
var staff_visual: Node3D

func _ready() -> void:
	super._ready()
	animation_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for index: int in range(skeleton.get_bone_count()):
		_clip_rest[index] = skeleton.get_bone_pose_rotation(index)
		rest_rotations[index] = _clip_rest[index]
	if animation_player != null:
		for library_name: StringName in animation_player.get_animation_library_list():
			var library: AnimationLibrary = animation_player.get_animation_library(library_name).duplicate(true)
			for clip: StringName in [&"walk", &"run"]:
				if library.has_animation(clip): library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animation_player.remove_animation_library(library_name)
			animation_player.add_animation_library(library_name, library)
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation_player.animation_finished.connect(_finished)
	var hand: int = skeleton.find_bone("HandRight")
	if hand >= 0:
		var socket: BoneAttachment3D = BoneAttachment3D.new()
		socket.bone_name = "HandRight"
		skeleton.add_child(socket)
		staff_visual = load("res://assets/models/female/willow_staff.glb").instantiate()
		socket.add_child(staff_visual)
		staff_visual.transform = skeleton.get_bone_global_rest(hand).affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(-.67,.955,.045))
		staff_visual.visible = false

func set_equipment_visual(weapon: ItemDefinition) -> void:
	if staff_visual != null:
		staff_visual.visible = weapon != null and weapon.id == &"willow_staff"
		if not staff_visual.visible:
			var finger: int = skeleton.find_bone("FingersRight")
			if _clip_rest.has(finger): skeleton.set_bone_pose_rotation(finger,_clip_rest[finger])

func _apply_grip() -> void:
	if staff_visual == null or not staff_visual.visible: return
	var finger: int = skeleton.find_bone("FingersRight")
	if finger >= 0:
		skeleton.set_bone_pose_rotation(finger, _clip_rest[finger] * Quaternion.from_euler(Vector3(.45,0,0)))

func play_battle_action(action: StringName) -> void:
	if _dead or animation_player == null: return
	var clip: StringName = &"cast" if action in [&"mend", &"star_spark"] else action
	if not animation_player.has_animation(clip): return
	_reset_clip()
	battle_pose = action
	animation_player.play(clip)
	animation_player.advance(0)

func _process(delta: float) -> void:
	if _dead: return
	if animation_player != null and battle_pose != &"":
		animation_player.advance(delta)
		_apply_grip()
		return
	if animation_player != null and _motion > .01:
		var clip: StringName = &"run" if _motion >= .65 else &"walk"
		if animation_player.current_animation != clip:
			_reset_clip()
			animation_player.play(clip)
		animation_player.advance(delta)
		_apply_grip()
		return
	if animation_player != null and animation_player.is_playing(): _reset_clip()
	super._process(delta)
	_apply_grip()

func _finished(_clip: StringName) -> void:
	_reset_clip()

func _reset_clip() -> void:
	if animation_player != null: animation_player.stop()
	battle_pose = &""
	for index: int in _clip_rest:
		skeleton.set_bone_pose_rotation(index, _clip_rest[index])

func set_dead(value: bool) -> void:
	if value: _reset_clip()
	super.set_dead(value)
