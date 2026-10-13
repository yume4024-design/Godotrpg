class_name ExplorationMap
extends Node3D

@export var map_id: StringName
@export var display_name: String
@export var default_spawn: Marker3D
@export var entrance_spawn: Marker3D
@export var camera_zone: Node3D
@export var camera_zone_radius: float = 4.0
@export var zone_camera_size: float = 14.0
@export var story_zone: Marker3D
@export var story_zone_radius: float = 2.0
@export var story_trigger: StringName
var targets: Array[WorldInteractable] = []

func _ready() -> void:
	for child: Node in find_children("*", "WorldInteractable", true, false):
		targets.append(child as WorldInteractable)

func spawn_position(key: StringName) -> Vector3:
	return entrance_spawn.global_position if key == &"entrance" else default_spawn.global_position

func camera_size_at(position: Vector3) -> float:
	if is_instance_valid(camera_zone) and position.distance_to(camera_zone.global_position) < camera_zone_radius:
		return zone_camera_size
	return 17.0
