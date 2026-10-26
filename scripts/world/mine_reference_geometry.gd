extends Node3D
## Explicit simplified colliders are authored with the Blender layout, not guessed.
const ROCK: Shader = preload("res://assets/shaders/mine/faceted_rock.gdshader")
const EARTH: Shader = preload("res://assets/shaders/greystone/ground.gdshader")
const WATER: Shader = preload("res://assets/shaders/mine/water.gdshader")
const WOOD: Shader = preload("res://assets/shaders/mine/wood.gdshader")
const FLAME: Shader = preload("res://assets/shaders/mine/flame.gdshader")
const FALL: Shader = preload("res://assets/shaders/greystone/reference_fall.gdshader")
const FOAM: Shader = preload("res://assets/shaders/mine/impact_foam.gdshader")
const CRYSTAL: Shader = preload("res://assets/shaders/mine/crystal.gdshader")
const RIPPLE: Shader = preload("res://assets/shaders/mine/ripple.gdshader")
var _shared: Dictionary = {}
@export var build_collisions: bool = true

func _ready() -> void:
	if build_collisions: _build_collision()
	_apply_surfaces()

func _build_collision() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/mine_reference/manifest.json"))
	var body := StaticBody3D.new()
	body.name = "AuthoredCollision"
	add_child(body)
	for row: Dictionary in manifest.collisions:
		var collision := CollisionShape3D.new()
		collision.name = row.name
		if row.type == "box":
			var shape := BoxShape3D.new()
			shape.size = _vector(row.size)
			collision.shape = shape
			collision.position = _vector(row.position)
			collision.rotation.y = float(row.rotation)
		else:
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for point: Array in row.points: points.append(_vector(point))
			shape.points = points
			collision.shape = shape
		body.add_child(collision)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/mine_reference_layout.json"))
	var rock_collision_count: int = _build_rock_collisions(body, manifest)
	set_meta("rock_collision_count", rock_collision_count)
	_build_platform_safety(layout)
	_build_outer_safety()


func _build_rock_collisions(body: StaticBody3D, manifest: Dictionary) -> int:
	# The GLB exporter merges dressing by material, so named stone pieces no
	# longer exist as separate imported nodes. Use the Blender receipt's exact
	# ledge-boulder placements plus the authored portal recipe instead.
	var built: int = 0
	var art: Dictionary = manifest.get("art_refinement", {})
	for row: Dictionary in art.get("new_dressing", []):
		if row.get("kind", "") != "edge_dressing" or float(row.get("radius", 0.0)) < 1.1:
			continue
		var position_value: Vector3 = _vector(row.position) + Vector3(0, 0.55, 0)
		_add_rock_box(body, "LedgeBoulder_%02d" % built, position_value, Vector3(1.9, 1.45, 1.55))
		built += 1
	var portals: Array[Dictionary] = [
		{"name":"Rail", "pivot":Vector3(-41,3,-12), "yaw":0.0},
		{"name":"Crystal", "pivot":Vector3(-28,7,-38), "yaw":0.0},
		{"name":"Storage", "pivot":Vector3(38,7,-26), "yaw":0.0},
		{"name":"Waterway", "pivot":Vector3(40,0,16), "yaw":-PI*0.5},
		{"name":"Core", "pivot":Vector3(44,0,36), "yaw":0.0}
	]
	for portal: Dictionary in portals:
		var pivot: Vector3 = portal.pivot
		var yaw: float = float(portal.yaw)
		for side: int in [-1, 1]:
			for level: int in range(2):
				var local_offset := Vector3(side * 4.8, 1.7 + level * 2.8, -1.0)
				var rotated := Vector3(local_offset.x, 0, local_offset.z).rotated(Vector3.UP, yaw)
				_add_rock_box(body, "Portal_%s_%d_%d" % [String(portal.name), side, level], Vector3(pivot.x + rotated.x, pivot.y + local_offset.y, pivot.z + rotated.z), Vector3(2.45, 2.85, 3.9), yaw)
	for side: int in [-1, 1]:
		for level: int in range(2):
			_add_rock_box(body, "CampPortal_%d_%d" % [side, level], Vector3(-48, 1.7 + level * 2.8, 28 + side * 4.8), Vector3(3.9, 2.85, 2.45))
	return built + 24

func _add_rock_box(body: StaticBody3D, label: String, position_value: Vector3, dimensions: Vector3, yaw: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.name = "Rock_" + label
	collision.shape = shape
	collision.position = position_value
	collision.rotation.y = yaw
	body.add_child(collision)

func _build_platform_safety(layout: Dictionary) -> void:
	# Add low, invisible safety rails to every authored walkable platform.
	# Gaps are cut at the actual layout links, preserving stairs and bridges.
	var body := StaticBody3D.new()
	body.name = "LedgeSafety"
	add_child(body)
	var shape_count: int = 0
	for zone: Dictionary in layout.get("zones", []):
		var bounds: Array = zone.get("bounds", [])
		if bounds.size() != 4:
			continue
		var x0: float = float(bounds[0]) + 0.12
		var x1: float = float(bounds[1]) - 0.12
		var z0: float = float(bounds[2]) + 0.12
		var z1: float = float(bounds[3]) - 0.12
		var height: float = float(zone.get("height", 0.0))
		shape_count += _add_edge_rail(body, layout, zone, "north", x0, x1, z0, z1, height)
		shape_count += _add_edge_rail(body, layout, zone, "south", x0, x1, z0, z1, height)
		shape_count += _add_edge_rail(body, layout, zone, "west", x0, x1, z0, z1, height)
		shape_count += _add_edge_rail(body, layout, zone, "east", x0, x1, z0, z1, height)
	body.set_meta("shape_count", shape_count)
	set_meta("ledge_safety_shape_count", shape_count)

func _add_edge_rail(body: StaticBody3D, layout: Dictionary, zone: Dictionary, edge: String, x0: float, x1: float, z0: float, z1: float, height: float) -> int:
	var along_x: bool = edge in ["north", "south"]
	var low: float = x0 if along_x else z0
	var high: float = x1 if along_x else z1
	var edge_value: float = z0 if edge == "north" else (z1 if edge == "south" else (x0 if edge == "west" else x1))
	var openings: Array[Vector2] = []
	for link: Dictionary in layout.get("links", []):
		var a: Vector3 = _vector(link.a)
		var b: Vector3 = _vector(link.b)
		var delta: Vector3 = b - a
		var denominator: float = delta.z if along_x else delta.x
		# A parallel link never creates a side opening. Extend only by the
		# platform rail's 12 cm inset to include links ending on its boundary.
		if absf(denominator) < 0.001:
			continue
		var t: float = (edge_value - (a.z if along_x else a.x)) / denominator
		var tolerance: float = 0.15 / absf(denominator)
		if t < -tolerance or t > 1.0 + tolerance:
			continue
		var crossing: Vector3 = a.lerp(b, clampf(t, 0.0, 1.0))
		if absf(crossing.y - height) > 1.25:
			continue
		var along: float = crossing.x if along_x else crossing.z
		# Project the real deck width onto this edge; overlap its side rails
		# slightly so a capsule cannot escape through either bridge shoulder.
		var half_width: float = float(link.width) * 0.5 * Vector2(delta.x, delta.z).length() / absf(denominator) - 0.1
		var interval := Vector2(maxf(low, along - half_width), minf(high, along + half_width))
		if interval.y > interval.x:
			openings.append(interval)
	openings.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = low
	var created: int = 0
	for opening: Vector2 in openings:
		if opening.x > cursor + 0.01:
			_add_rail_segment(body, zone, edge, cursor, opening.x, edge_value, height, along_x)
			created += 1
		cursor = maxf(cursor, opening.y)
	if high > cursor + 0.01:
		_add_rail_segment(body, zone, edge, cursor, high, edge_value, height, along_x)
		created += 1
	return created

func _add_rail_segment(body: StaticBody3D, zone: Dictionary, edge: String, start: float, finish: float, edge_value: float, height: float, along_x: bool) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(finish - start, 1.25, 0.28) if along_x else Vector3(0.28, 1.25, finish - start)
	var collision := CollisionShape3D.new()
	collision.name = "Rail_%s_%s_%02d" % [String(zone.get("id", "zone")), edge, body.get_child_count()]
	collision.shape = shape
	collision.position = Vector3((start + finish) * 0.5, height + 0.625, edge_value) if along_x else Vector3(edge_value, height + 0.625, (start + finish) * 0.5)
	body.add_child(collision)

func _build_outer_safety() -> void:
	# Long boundary boxes also stop a falling character from leaving the cave
	# volume at the outer map edge. There is deliberately no catch-floor over
	# the authored water channels.
	var body := StaticBody3D.new()
	body.name = "MinePerimeterSafety"
	add_child(body)
	var extent: float = 55.4
	var wall_height: float = 1000.0
	var wall_top: float = 18.0
	var vertical_center: float = wall_top - wall_height * 0.5
	_add_safety_box(body, "West", Vector3(-extent, vertical_center, 0), Vector3(0.8, wall_height, extent * 2))
	_add_safety_box(body, "East", Vector3(extent, vertical_center, 0), Vector3(0.8, wall_height, extent * 2))
	_add_safety_box(body, "North", Vector3(0, vertical_center, -extent), Vector3(extent * 2, wall_height, 0.8))
	_add_safety_box(body, "South", Vector3(0, vertical_center, extent), Vector3(extent * 2, wall_height, 0.8))

func _add_safety_box(parent: StaticBody3D, label: String, position_value: Vector3, size_value: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	collision.position = position_value
	parent.add_child(collision)

func _apply_surfaces() -> void:
	for node: Node in find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		for index: int in visual.mesh.get_surface_count():
			var original: Material = visual.mesh.surface_get_material(index)
			if original == null: continue
			var name_key: String = original.resource_name
			if name_key.begins_with("Mine_Rock") or name_key.begins_with("Mine_Earth") or name_key.begins_with("Mine_Water") or name_key.begins_with("Mine_Fall") or name_key.begins_with("Mine_Wood") or name_key.begins_with("Mine_Flame") or name_key.begins_with("Mine_Foam") or name_key.begins_with("Mine_Ripple"):
				visual.set_surface_override_material(index,_material(name_key))
			elif "crystal" in name_key.to_lower() and original is StandardMaterial3D:
				if not _shared.has("crystal"):
					var crystal_material := ShaderMaterial.new()
					crystal_material.shader = CRYSTAL
					_shared["crystal"] = crystal_material
				visual.set_surface_override_material(index,_shared["crystal"])

func _vector(array: Array) -> Vector3:
	return Vector3(float(array[0]),float(array[1]),float(array[2]))

func _material(key: String) -> ShaderMaterial:
	if _shared.has(key): return _shared[key]
	var material := ShaderMaterial.new()
	if key.begins_with("Mine_Flame"):
		material.shader = FLAME
	elif key.begins_with("Mine_Ripple"):
		material.shader = RIPPLE
	elif key.begins_with("Mine_Fall"):
		material.shader = FALL
	elif key.begins_with("Mine_Foam"):
		material.shader = FOAM
	elif key.begins_with("Mine_Wood"):
		material.shader = WOOD
		material.set_shader_parameter("base_color",Color(.56,.36,.18) if key.begins_with("Mine_WoodLight") else Color(.40,.25,.12))
	elif key.begins_with("Mine_Rock"):
		material.shader = ROCK
	elif key.begins_with("Mine_Earth"):
		material.shader = EARTH
		material.set_shader_parameter("base_color",Color(.63,.48,.29))
		material.set_shader_parameter("grain_color",Color(.78,.64,.41))
		material.set_shader_parameter("grass_amount",0.0)
	else:
		material.shader = WATER
	_shared[key] = material
	return material
