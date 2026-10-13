class_name ExplorationMap
extends Node3D

@export var map_id: StringName
@export var display_name: String
@export var environment: Environment
@export var sunlight: float = 1.1
@export var default_spawn: Marker3D
@export var entrance_spawn: Marker3D
@export var camera_zone: Node3D
@export var camera_zone_radius: float = 4.0
@export var zone_camera_size: float = 14.0
@export var story_zone: Marker3D
@export var story_zone_radius: float = 2.0
@export var story_trigger: StringName
@export var extra_story_zones: Array[Marker3D] = []
@export var return_spawn: Marker3D
@export var sequence_target: Node3D
@export var sequence_light: OmniLight3D
var targets: Array[WorldInteractable] = []

func _ready() -> void:
	for child: Node in find_children("*", "WorldInteractable", true, false):
		targets.append(child as WorldInteractable)

func spawn_position(key: StringName) -> Vector3:
	if key == &"return" and is_instance_valid(return_spawn): return return_spawn.global_position
	return entrance_spawn.global_position if key == &"entrance" else default_spawn.global_position

func triggers_at(position: Vector3) -> Array[StringName]:
	var result: Array[StringName] = []
	if is_instance_valid(story_zone) and position.distance_to(story_zone.global_position) <= story_zone_radius: result.append(story_trigger)
	for zone: Marker3D in extra_story_zones:
		if position.distance_to(zone.global_position) <= float(zone.get_meta("radius", 2.0)): result.append(StringName(zone.get_meta("trigger", "")))
	return result

func camera_size_at(position: Vector3) -> float:
	if is_instance_valid(camera_zone) and position.distance_to(camera_zone.global_position) < camera_zone_radius:
		return zone_camera_size
	return 17.0
