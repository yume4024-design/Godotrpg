extends "res://scripts/characters/user_hero_actor.gd"
## Imported clips own the skeleton during battle; idle resumes after explicit reset.
var battle_pose: StringName = &""
var animation_player: AnimationPlayer
var _clip_rest: Dictionary[int, Quaternion] = {}

func _ready() -> void:
	super._ready()
	animation_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for index: int in range(skeleton.get_bone_count()):
		_clip_rest[index] = skeleton.get_bone_pose_rotation(index)
		rest_rotations[index] = _clip_rest[index]
	if animation_player != null:
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation_player.animation_finished.connect(_finished)

func play_battle_action(action: StringName) -> void:
	if _dead or animation_player == null: return
	var clip: StringName = &"cast" if action in [&"mend", &"star_spark"] else action
	if not animation_player.has_animation(clip): return
	_reset_clip()
	battle_pose = action
	animation_player.play(clip)
	animation_player.advance(0)

func _process(delta: float) -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.advance(delta)
		return
	super._process(delta)

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
