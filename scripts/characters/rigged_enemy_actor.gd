class_name RiggedEnemyActor
extends CartoonActor
## Imported clips own this visual's bones; battle values and timing stay in BattleManager.
@export var action_clips: Dictionary = {&"attack": &"attack", &"hit": &"hit"}
@export_range(0.0, 1.0) var run_motion_threshold: float = 0.0
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var _clips: Dictionary[StringName, StringName] = {}
var _one_shot: bool = false

func _ready() -> void:
	super._ready()
	set_process(false) # AnimationPlayer alone owns imported-bone advancement.
	var players: Array[Node] = _model_root.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = _model_root.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or skeletons.size() != 1:
		push_error("Rigged enemy requires one animation player and skeleton")
		return
	animation_player = players[0] as AnimationPlayer
	skeleton = skeletons[0] as Skeleton3D
	animation_player.stop()
	# Loop metadata is per visual instance, never written back to the imported asset.
	for library_name: StringName in animation_player.get_animation_library_list():
		var local: AnimationLibrary = animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, local)
	for clip: StringName in animation_player.get_animation_list():
		var text: String = String(clip)
		var kind: StringName = text.get_slice("|", text.get_slice_count("|") - 1).get_file().to_lower()
		if kind == &"reset": continue
		_clips[kind] = clip
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if kind in [&"idle", &"walk", &"run"] else Animation.LOOP_NONE
	for required: StringName in [&"idle", &"walk", &"attack", &"hit", &"death"]:
		if not _clips.has(required):
			push_error("Rigged enemy missing clip: " + String(required))
			return
	if run_motion_threshold > 0.0 and not _clips.has(&"run"):
		push_error("Run-enabled enemy requires imported run clip")
		return
	animation_player.animation_finished.connect(_on_animation_finished)
	if _dead: _play(&"death", 0.0)
	else: _locomotion()

func set_motion(amount: float) -> void:
	_motion = clampf(amount, 0.0, 1.0)
	if is_instance_valid(animation_player) and not _dead and not _one_shot:
		_locomotion()

func set_dead(value: bool) -> void:
	if _dead == value: return
	_dead = value
	_one_shot = false
	if not is_instance_valid(animation_player): return
	if _dead:
		_play(&"death", 0.08)
	else:
		skeleton.reset_bone_poses()
		_locomotion()

func play_battle_action(action: StringName) -> bool:
	if _dead or not is_instance_valid(animation_player): return false
	var kind: StringName = StringName(action_clips.get(action, &""))
	if not _clips.has(kind): return false
	_one_shot = true
	_play(kind, 0.08, true)
	return true

func _locomotion() -> void:
	var kind: StringName = &"walk" if _motion > 0.1 else &"idle"
	if run_motion_threshold > 0.0 and _motion >= run_motion_threshold: kind = &"run"
	_play(kind, 0.12)

func _play(kind: StringName, blend: float, restart: bool = false) -> void:
	if not _clips.has(kind): return
	var clip: StringName = _clips[kind]
	if not restart and animation_player.is_playing() and animation_player.current_animation == clip:
		return
	animation_player.play(clip, blend)
	if restart: animation_player.seek(0.0, true)

func _on_animation_finished(_clip: StringName) -> void:
	if _dead: return
	_one_shot = false
	_locomotion()
