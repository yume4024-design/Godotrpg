extends Control
## Lightweight RPG navigation map. Draws authored world data,
## player position and current interactables without adding a SubViewport.


signal expand_requested
var expanded: bool = false
var selected_target: WorldInteractable
var selected_zone_id: String = ""
var player: ExplorationPlayer
var scene_manager: Node
var _active_map: ExplorationMap
var _layout: Dictionary = {}
var _zones: Array[Dictionary] = []
var _road_polygons: Array[PackedVector2Array] = []
var _extent: Vector2 = Vector2(56, 56)
var _map_title: String = "世界地圖"

func configure(actor: ExplorationPlayer, manager: Node) -> void:
	player = actor
	scene_manager = manager
	_refresh_map()
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(scene_manager):
		return
	var next_map: ExplorationMap = scene_manager.get("current_map") as ExplorationMap
	if next_map != _active_map:
		_refresh_map()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not expanded and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		expand_requested.emit()
		accept_event()

func landmarks() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_instance_valid(_active_map): return entries
	for target: WorldInteractable in _active_map.targets:
		if is_instance_valid(target) and target.is_visible_in_tree():
			entries.append({"target": target, "label": target.prompt(), "kind": target.kind})
	return entries

func select_landmark(target: WorldInteractable) -> void:
	selected_target = target
	selected_zone_id = ""
	queue_redraw()

func zones() -> Array[Dictionary]:
	return _zones

func select_zone(id: String) -> void:
	selected_zone_id = id
	selected_target = null
	queue_redraw()

func current_zone_label() -> String:
	if not is_instance_valid(player): return ""
	for zone: Dictionary in zones():
		var b: Array = zone.bounds
		var position: Vector3 = player.global_position
		if position.x >= b[0] and position.x <= b[1] and position.z >= b[2] and position.z <= b[3] and absf(position.y - float(zone.height)) < 1.6:
			return zone.label
	for link: Dictionary in _layout.get("links", []):
		var start: Vector3 = Vector3(link.a[0], link.a[1], link.a[2])
		var end: Vector3 = Vector3(link.b[0], link.b[1], link.b[2])
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(player.global_position, start, end)
		if Vector2(player.global_position.x - closest.x, player.global_position.z - closest.z).length() <= float(link.width) * .5 and absf(player.global_position.y - closest.y) < 1.6:
			return "階梯通道" if link.kind == "stairs" else "木橋通道"
	return "礦坑通道" if not zones().is_empty() else ""

func zone_badges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var area: Rect2 = map_area()
	var occupied: Array[Rect2] = []
	for entry: Dictionary in landmarks():
		var point: Vector3 = entry.target.global_position
		occupied.append(Rect2(_screen_point(area, point.x, point.z) - Vector2(16, 16), Vector2(32, 32)))
	if is_instance_valid(player):
		occupied.append(Rect2(_screen_point(area, player.global_position.x, player.global_position.z) - Vector2(12, 12), Vector2(24, 24)))
	for zone: Dictionary in zones():
		var b: Array = zone.bounds
		var center: Vector2 = _screen_point(area, (float(b[0]) + float(b[1])) * .5, (float(b[2]) + float(b[3])) * .5)
		for offset: Vector2 in [Vector2.ZERO, Vector2(0,-22), Vector2(-22,0), Vector2(22,0), Vector2(0,22), Vector2(-22,-22), Vector2(22,22), Vector2(22,-22), Vector2(-22,22), Vector2(0,-44), Vector2(-44,0), Vector2(44,0)]:
			var box := Rect2(center + offset - Vector2(10,10), Vector2(20,20))
			if not area.encloses(box): continue
			var blocked: bool = false
			for other: Rect2 in occupied:
				if box.grow(2).intersects(other): blocked = true; break
			if blocked: continue
			result.append({"zone":zone, "rect":box, "anchor":center})
			occupied.append(box)
			break
	return result

func landmark_color(kind: String) -> Color:
	return Color("#53c5e8") if kind == "exit" else (Color("#f5c96c") if kind == "story" else Color("#ec8e79"))

func map_area() -> Rect2:
	var top: float = 54.0 if not expanded and not current_zone_label().is_empty() else (36.0 if expanded else 31.0)
	var available := Rect2(11, top, size.x - 22, size.y - top - (30.0 if expanded else 46.0))
	if not expanded: return available
	# Keep distances proportional on the large map instead of stretching it.
	var factor: float = minf(available.size.x / (_extent.x * 2.0), available.size.y / (_extent.y * 2.0))
	var dimensions: Vector2 = _extent * 2.0 * factor
	return Rect2(available.position + (available.size - dimensions) * .5, dimensions)

func _refresh_map() -> void:
	_active_map = scene_manager.get("current_map") as ExplorationMap if is_instance_valid(scene_manager) else null
	_layout = {}
	_road_polygons.clear()
	_zones.clear()
	selected_target = null
	selected_zone_id = ""
	_extent = Vector2(56, 56)
	_map_title = _active_map.display_name if is_instance_valid(_active_map) else "世界地圖"
	if not is_instance_valid(_active_map):
		return
	_layout = _read_json(_active_map.navigation_layout_path) if not _active_map.navigation_layout_path.is_empty() else {}
	if _active_map.navigation_layout_kind == "mine":
		for zone: Dictionary in _layout.get("zones", []):
			if zone.get("bounds", []).size() != 4: continue
			var entry: Dictionary = zone.duplicate()
			entry.code = String.chr(65 + _zones.size())
			_zones.append(entry)
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
	draw_string(ThemeDB.fallback_font, Vector2(12, 23), "地圖  ·  " + _map_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20 if expanded else 14, Color("#f0d7a0"))
	if not expanded and not current_zone_label().is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, 44), "目前：" + current_zone_label(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 14, Color("#e5e9dc"))
	var map_rect: Rect2 = map_area()
	draw_rect(map_rect, Color("#152a2e"), true)
	if is_instance_valid(_active_map):
		match _active_map.navigation_layout_kind:
			"mine": _draw_mine(map_rect)
			"village": _draw_village(map_rect)
			"paths": _draw_paths(map_rect)
		if expanded:
			_draw_zone_badges()
		_draw_targets(map_rect)
		_draw_player(map_rect)
	draw_rect(map_rect, Color(0.45, 0.63, 0.59, 0.82), false, 1.0)
	# Compact north indicator, matching the fixed isometric camera orientation.
	draw_string(ThemeDB.fallback_font, Vector2(map_rect.end.x - 12, map_rect.position.y + 14), "N", HORIZONTAL_ALIGNMENT_CENTER, 14, 10, Color("#e7d5a4"))
	if expanded:
		draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 9), "▲ 你　數字：互動地標　字母：區域" if not zones().is_empty() else "▲ 你　數字：互動地標", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#fff3b0"))
		return
	for entry: Array in [[Vector2(17,size.y-29), "你", Color("#fff3b0")], [Vector2(115,size.y-29), "出口", Color("#53c5e8")], [Vector2(17,size.y-10), "互動", Color("#ec8e79")], [Vector2(115,size.y-10), "劇情", Color("#f5c96c")]]:
		var point: Vector2 = entry[0]
		_draw_marker(point + Vector2(0,-4), entry[2], 3.2)
		draw_string(ThemeDB.fallback_font, point + Vector2(9,0), entry[1], HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color("#e5e9dc"))

func _draw_zone_badges() -> void:
	for entry: Dictionary in zone_badges():
		var box: Rect2 = entry.rect
		var chosen: bool = entry.zone.id == selected_zone_id
		if box.get_center().distance_to(entry.anchor) > 1:
			draw_line(entry.anchor, box.get_center(), Color("#a8b6ae"), 1.0, true)
		draw_rect(box, Color("#24363b"))
		draw_rect(box, Color("#ffe090") if chosen else Color("#b1c5c1"), false, 2.0 if chosen else 1.0)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(0,15), entry.zone.code, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color("#fff3b0"))

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
		if (expanded and String(zone.id) == selected_zone_id) or (not expanded and String(zone.label) == current_zone_label()):
			var top_left: Vector2 = _screen_point(area, float(bounds[0]), float(bounds[2]))
			var bottom_right: Vector2 = _screen_point(area, float(bounds[1]), float(bounds[3]))
			draw_rect(Rect2(top_left, bottom_right-top_left), Color("#ffe090"), false, 2.0)
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
	var index: int = 0
	for entry: Dictionary in landmarks():
		index += 1
		var target: WorldInteractable = entry.target
		var point: Vector2 = _screen_point(area, target.global_position.x, target.global_position.z)
		var color: Color = landmark_color(target.kind)
		_draw_marker(point, color, 9.0 if expanded else 2.7)
		if expanded:
			draw_string(ThemeDB.fallback_font, point + Vector2(-9, 5), str(index), HORIZONTAL_ALIGNMENT_CENTER, 18, 14, Color("#10282e"))
			if selected_target == target:
				draw_arc(point, 14, 0, TAU, 32, Color("#fff3b0"), 3, true)

func _draw_player(area: Rect2) -> void:
	if not is_instance_valid(player):
		return
	var center: Vector2 = _screen_point(area, player.global_position.x, player.global_position.z)
	var facing: Vector3 = player.facing_direction()
	var direction: Vector2 = Vector2(facing.x, facing.z).normalized()
	if direction.length_squared() < .01: direction = Vector2.DOWN
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([center + direction * 8, center - direction * 5 + side * 5, center - direction * 5 - side * 5])
	draw_colored_polygon(arrow, Color("#fff3b0"))
	var border := arrow.duplicate()
	border.append(arrow[0])
	draw_polyline(border, Color("#132124"), 1.5, true)

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
