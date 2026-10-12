class_name ExplorationSceneManager
extends Node

signal transition_changed(active: bool)
signal map_changed(map: ExplorationMap)
@export var maps: Array[PackedScene] = []
var current_map: ExplorationMap
var transitioning: bool = false
var _container: Node3D
var _player: ExplorationPlayer
var _fade: ColorRect

func setup(container: Node3D, player: ExplorationPlayer, fade: ColorRect) -> void:
	_container = container
	_player = player
	_fade = fade

func travel(id: StringName, spawn_key: StringName = &"entrance") -> bool:
	if transitioning:
		return false
	var selected: PackedScene
	for scene: PackedScene in maps:
		# Scene filenames are stable map IDs, avoiding temporary scene instances.
		if scene.resource_path.get_file().get_basename() == String(id):
			selected = scene
	if selected == null:
		return false
	transitioning = true
	transition_changed.emit(true)
	_swap.call_deferred(selected, spawn_key)
	return true

func _swap(scene: PackedScene, spawn_key: StringName) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.16)
	await tween.finished
	if is_instance_valid(current_map):
		_container.remove_child(current_map)
		current_map.queue_free()
	current_map = scene.instantiate() as ExplorationMap
	_container.add_child(current_map)
	_player.reset_to(current_map.spawn_position(spawn_key))
	map_changed.emit(current_map)
	await get_tree().physics_frame
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.16)
	await tween.finished
	transitioning = false
	transition_changed.emit(false)
