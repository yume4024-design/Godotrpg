class_name ExplorationMap
extends Node3D

const EXPLORATION_ZOOM: float = 2.0

@export var map_id: StringName
@export var display_name: String
@export_file("*.json") var navigation_layout_path: String = ""
@export_enum("none", "mine", "village", "paths") var navigation_layout_kind: String = "none"
@export var navigation_extent: Vector2 = Vector2(56, 56)
@export var environment: Environment
@export var sunlight: float = 1.1
@export var default_camera_size: float = 17.0
@export var default_spawn: Marker3D
@export var entrance_spawn: Marker3D
@export var camera_zone: Node3D
@export var camera_zone_radius: float = 4.0
@export var zone_camera_size: float = 14.0
@export var story_zone: Marker3D
@export var story_zone_radius: float = 2.0
@export var story_trigger: StringName
@export var extra_story_zones: Array[Marker3D] = []
@export var opening_spawn: Marker3D
@export var return_spawn: Marker3D
@export var sequence_target: Node3D
@export var sequence_light: OmniLight3D
var targets: Array[WorldInteractable] = []
var navigation_roads: Array[Node3D] = []

func _ready() -> void:
	for child: Node in find_children("*", "WorldInteractable", true, false):
		targets.append(child as WorldInteractable)

func spawn_position(key: StringName) -> Vector3:
	if key == &"opening" and is_instance_valid(opening_spawn): return opening_spawn.global_position
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
		return zone_camera_size / EXPLORATION_ZOOM
	return default_camera_size / EXPLORATION_ZOOM


func navigation_road_footprints() -> Array[PackedVector2Array]:
	var footprints: Array[PackedVector2Array] = []
	for road: Node3D in navigation_roads:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for mesh: MeshInstance3D in road.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.get_aabb()
			for index: int in 8:
				var corner: Vector3 = mesh.to_global(bounds.get_endpoint(index))
				low = low.min(Vector2(corner.x, corner.z))
				high = high.max(Vector2(corner.x, corner.z))
		if low.is_finite() and high.is_finite():
			footprints.append(PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]))
	return footprints
