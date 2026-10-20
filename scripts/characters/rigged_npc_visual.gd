extends Node3D
## Presentation state only. Dialogue ownership stays with existing RPG services.

@export var model: PackedScene
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var _clips: Dictionary[StringName, StringName] = {}
var _talking: bool = false

func _ready() -> void:
	if model == null:
		push_error("NPC visual requires a model")
		return
	var root: Node3D = model.instantiate() as Node3D
	add_child(root)
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or skeletons.size() != 1:
		push_error("NPC visual requires one animation player and skeleton")
		return
	animation_player = players[0] as AnimationPlayer
	skeleton = skeletons[0] as Skeleton3D
	# Loop metadata is presentation configuration; keep it local to each actor.
	for library_name: StringName in animation_player.get_animation_library_list():
		var library: AnimationLibrary = animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	for name: StringName in animation_player.get_animation_list():
		var kind: StringName = String(name).get_slice("|", String(name).get_slice_count("|") - 1).get_file()
		if kind in [&"idle", &"talk"]:
			_clips[kind] = name
			animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	if not _clips.has(&"idle") or not _clips.has(&"talk"):
		push_error("NPC visual requires real idle and talk clips")
		return
	_play(&"talk" if _talking else &"idle")

func set_talking(enabled: bool) -> void:
	_talking = enabled
	if is_instance_valid(animation_player):
		_play(&"talk" if enabled else &"idle")

func is_talking() -> bool:
	return _talking

func _play(kind: StringName) -> void:
	if not _clips.has(kind): return
	var clip: StringName = _clips[kind]
	if animation_player.is_playing() and animation_player.current_animation == clip:
		return
	animation_player.play(clip, 0.12)
