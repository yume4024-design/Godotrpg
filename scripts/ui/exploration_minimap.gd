extends Control
## Lightweight, non-interactive RPG navigation map. Draws authored world data,
## player position and current interactables without adding a SubViewport.


var player: ExplorationPlayer
var scene_manager: Node
var _active_map: ExplorationMap
var _layout: Dictionary = {}
var _road_polygons: Array[PackedVector2Array] = []
var _extent: Vector2 = Vector2(56, 56)
var _map_title: String = "世界地圖"

func configure(actor: ExplorationPlayer, manager: Node) -> void:
	player = actor
	scene_manager = manager
	_refresh_map()
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(scene_manager):
		return
	var next_map: ExplorationMap = scene_manager.get("current_map") as ExplorationMap
	if next_map != _active_map:
		_refresh_map()
	queue_redraw()

func _refresh_map() -> void:
	_active_map = scene_manager.get("current_map") as ExplorationMap if is_instance_valid(scene_manager) else null
	_layout = {}
	_extent = Vector2(56, 56)
	_map_title = _active_map.display_name if is_instance_valid(_active_map) else "世界地圖"
	if not is_instance_valid(_active_map):
		return
	_layout = _read_json(_active_map.navigation_layout_path) if not _active_map.navigation_layout_path.is_empty() else {}
	_extent = _active_map.navigation_extent
	_road_polygons = _active_map.navigation_road_footprints()
	_map_title = _map_title.split(" · ")[0]

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.07, 0.96), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#718b85"), false, 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(12, 21), "地圖  ·  " + _map_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0d7a0"))
	var map_rect: Rect2 = Rect2(11, 31, size.x - 22, size.y - 43)
	draw_rect(map_rect, Color("#152a2e"), true)
	if is_instance_valid(_active_map):
		match _active_map.navigation_layout_kind:
			"mine": _draw_mine(map_rect)
			"village": _draw_village(map_rect)
			"paths": _draw_paths(map_rect)
		_draw_targets(map_rect)
		_draw_player(map_rect)
	draw_rect(map_rect, Color(0.45, 0.63, 0.59, 0.82), false, 1.0)
	# Compact north indicator, matching the fixed isometric camera orientation.
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 23, 46), "N", HORIZONTAL_ALIGNMENT_CENTER, 14, 10, Color("#e7d5a4"))
	var legend_y: float = size.y - 8.0
	draw_circle(Vector2(17, legend_y - 4), 3.2, Color("#fff3b0"))
	draw_string(ThemeDB.fallback_font, Vector2(24, legend_y), "你", HORIZONTAL_ALIGNMENT_LEFT, 24, 10, Color("#e5e9dc"))
	draw_circle(Vector2(62, legend_y - 4), 3.0, Color("#ec8e79"))
	draw_string(ThemeDB.fallback_font, Vector2(69, legend_y), "NPC", HORIZONTAL_ALIGNMENT_LEFT, 34, 10, Color("#e5e9dc"))
	draw_circle(Vector2(116, legend_y - 4), 3.0, Color("#f5c96c"))
	draw_string(ThemeDB.fallback_font, Vector2(123, legend_y), "目標", HORIZONTAL_ALIGNMENT_LEFT, 34, 10, Color("#e5e9dc"))
	draw_circle(Vector2(177, legend_y - 4), 3.0, Color("#53c5e8"))
	draw_string(ThemeDB.fallback_font, Vector2(184, legend_y), "出口", HORIZONTAL_ALIGNMENT_LEFT, 38, 10, Color("#e5e9dc"))

func _draw_mine(area: Rect2) -> void:
	for water: Dictionary in _layout.get("water", []):
		var bounds: Array = water.get("bounds", [])
		if bounds.size() == 4:
			_draw_world_rect(area, float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]), Color(0.08, 0.42, 0.58, 0.72))
	for zone: Dictionary in _layout.get("zones", []):
		var bounds: Array = zone.get("bounds", [])
		if bounds.size() != 4:
			continue
		var level: float = float(zone.get("height", 0.0))
		var tint: Color = Color("#6c7d74") if level >= 6 else (Color("#99744c") if level >= 2 else Color("#827e70"))
		_draw_world_rect(area, float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]), tint.darkened(0.28))
		var label: String = String(zone.get("label", ""))
		var center: Vector2 = _screen_point(area, (float(bounds[0]) + float(bounds[1])) * 0.5, (float(bounds[2]) + float(bounds[3])) * 0.5)
		if area.has_point(center):
			draw_string(ThemeDB.fallback_font, center + Vector2(-27, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 54, 8, Color("#dce6d7"))
	for link: Dictionary in _layout.get("links", []):
		var a: Array = link.get("a", [])
		var b: Array = link.get("b", [])
		if a.size() == 3 and b.size() == 3:
			_draw_world_line(area, Vector2(float(a[0]), float(a[2])), Vector2(float(b[0]), float(b[2])), Color("#d2ae70"), 2.2)
	_draw_route(area, _layout.get("route", []), Color("#e9d09a"), 1.8)
	_draw_route(area, _layout.get("cross_route", []), Color("#d9b86d"), 1.5)
	_draw_route(area, _layout.get("north_route", []), Color("#d9b86d"), 1.5)
	var story: Dictionary = _layout.get("story", {})
	var crystal: Array = story.get("crystal", [])
	if crystal.size() == 3:
		_draw_marker(_screen_point(area, float(crystal[0]), float(crystal[2])), Color("#41dcf7"), 5.0)

func _draw_village(area: Rect2) -> void:
	for road: Dictionary in _layout.get("roads", []):
		var points: Array = road.get("points", [])
		var line: PackedVector2Array = PackedVector2Array()
		for point: Array in points:
			if point.size() >= 2:
				# Source roads are stored in Blender XYZ; Godot map north is -Z.
				line.append(_screen_point(area, float(point[0]), -float(point[1])))
		if line.size() >= 2:
			draw_polyline(line, Color("#bd9b61"), 2.0, true)
	for building: Array in _layout.get("building_placements", []):
		if building.size() < 3 or not building[2] is Array:
			continue
		var pos: Array = building[2]
		if pos.size() >= 2:
			_draw_marker(_screen_point(area, float(pos[0]), -float(pos[1])), Color("#e3c18b"), 2.0)

func _draw_paths(area: Rect2) -> void:
	for footprint: PackedVector2Array in _road_polygons:
		var points := PackedVector2Array()
		for point: Vector2 in footprint:
			points.append(_screen_point(area, point.x, point.y))
		draw_colored_polygon(points, Color("#b69c69"))

func _draw_targets(area: Rect2) -> void:
	if not is_instance_valid(_active_map):
		return
	for target: WorldInteractable in _active_map.targets:
		if not is_instance_valid(target) or not target.visible:
			continue
		var color: Color = Color("#53c5e8") if target.kind == "exit" else (Color("#f5c96c") if target.kind == "story" else Color("#ec8e79"))
		_draw_marker(_screen_point(area, target.global_position.x, target.global_position.z), color, 2.7)

func _draw_player(area: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var center: Vector2 = _screen_point(area, player.global_position.x, player.global_position.z)
	var facing: Vector3 = player.facing_direction()
	var direction: Vector2 = Vector2(facing.x, facing.z).normalized()
	if direction.length_squared() > 0.01:
		draw_line(center, center + Vector2(direction.x, direction.y) * 8.0, Color.WHITE, 2.0, true)
	_draw_marker(center, Color("#fff3b0"), 4.0)

func _draw_route(area: Rect2, route: Array, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Array in route:
		if point.size() == 3:
			points.append(_screen_point(area, float(point[0]), float(point[2])))
	if points.size() >= 2:
		draw_polyline(points, color, width, true)

func _draw_world_rect(area: Rect2, x0: float, x1: float, z0: float, z1: float, color: Color) -> void:
	var top_left: Vector2 = _screen_point(area, x0, z0)
	var bottom_right: Vector2 = _screen_point(area, x1, z1)
	draw_rect(Rect2(top_left, bottom_right - top_left), color, true)

func _draw_world_line(area: Rect2, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(_screen_point(area, a.x, a.y), _screen_point(area, b.x, b.y), color, width, true)

func _draw_marker(position: Vector2, color: Color, radius: float) -> void:
	draw_circle(position, radius + 1.6, Color("#132124"))
	draw_circle(position, radius, color)

func _screen_point(area: Rect2, x: float, z: float) -> Vector2:
	var normalized_x: float = clampf((x + _extent.x) / (_extent.x * 2.0), 0.0, 1.0)
	var normalized_y: float = clampf((z + _extent.y) / (_extent.y * 2.0), 0.0, 1.0)
	return Vector2(area.position.x + normalized_x * area.size.x, area.position.y + normalized_y * area.size.y)
