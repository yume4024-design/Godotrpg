extends SceneTree
## Before/after collision contract and actual exploration around ENV02 props.
## Isolated preview only; no save/gameplay manager state is written here.

const OUT: String = "res://artifacts/env02_village_integration"
const BASELINE: String = "res://source_assets/environment_rebuild_20261020/village_integration/baseline.json"
const PROTECTED: Array[String] = ["res://project.godot", "res://scenes/main/main.tscn", "res://scenes/world/greystone_runtime.tscn", "res://data/story/prologue_events.json", "res://scripts/save/save_codec.gd"]
var game: Node3D
var player: ExplorationPlayer
var village: Node3D
var checks: int = 0
var failures: Array[String] = []
var record: bool = false
var baseline: Dictionary = {}
var snapshot: Dictionary = {}
var measurements: Dictionary = {}

func _initialize() -> void:
	record = "--record-baseline" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _shape_fingerprint(shape: Shape3D) -> String:
	var values: Variant
	if shape is BoxShape3D: values = (shape as BoxShape3D).size
	elif shape is ConcavePolygonShape3D: values = (shape as ConcavePolygonShape3D).get_faces()
	elif shape is ConvexPolygonShape3D: values = (shape as ConvexPolygonShape3D).points
	elif shape is CapsuleShape3D: values = [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
	elif shape is SphereShape3D: values = (shape as SphereShape3D).radius
	elif shape is CylinderShape3D: values = [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
	else:
		_check(false, "Unhandled collision class " + shape.get_class())
	return _digest([shape.get_class(), values, shape.margin])

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _snapshot() -> Dictionary:
	var result: Dictionary = {"collisions":{}, "markers":{}, "buildings":{}, "placements":{}, "protected":{}}
	for node: Node in village.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as CollisionObject3D
		result.collisions[String(village.get_path_to(collision))] = _digest([collision.global_transform, collision.disabled, body.collision_layer, body.collision_mask, _shape_fingerprint(collision.shape)])
	for group: String in ["Markers", "ActivitySpaces"]:
		for child: Node3D in village.get_node(group).get_children():
			result.markers[group + "/" + String(child.name)] = var_to_bytes(child.global_transform).hex_encode()
	for child: Node3D in village.get_node("Buildings").get_children():
		result.buildings[String(child.name)] = [child.scene_file_path, var_to_bytes(child.transform).hex_encode()]
	for child: Node3D in village.get_node("Props").get_children():
		if String(child.name).begins_with("Crop") or child.name == &"RiverWaterwheel":
			result.placements[String(child.name)] = var_to_bytes(child.transform).hex_encode()
	for path: String in PROTECTED:
		# Scene/script line endings can change on checkout without changing any
		# gameplay content. The original raw hashes remain in the saved fixture.
		result.protected[path] = FileAccess.get_file_as_string(path).trim_prefix("\uFEFF").replace("\r\n","\n").sha256_text()
	return result

func _mesh_triangles(node: Node3D) -> int:
	var total: int = 0
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			total += (mesh.surface_get_array_index_len(surface) if mesh.surface_get_array_index_len(surface) > 0 else mesh.surface_get_array_len(surface)) / 3
	return total

func _bounds(node: Node3D) -> AABB:
	var value := AABB()
	var first: bool = true
	var mesh_nodes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: mesh_nodes.append(node)
	for child: Node in mesh_nodes:
		var mesh := child as MeshInstance3D
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				var transformed: Vector3 = mesh.global_transform * point
				low = low.min(transformed)
				high = high.max(transformed)
		var box := AABB(low,high-low)
		value = box if first else value.merge(box)
		first = false
	return value

func _capture(label: String, target: Vector3, span: float) -> void:
	game.set_physics_process(false)
	var camera: Camera3D = game.camera
	camera.size = span
	camera.position = target + Vector3(12, 16.970563, 12)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(roundi(float(image.get_width()) * 512.0 / image.get_height()), 512, Image.INTERPOLATE_LANCZOS)
	_check(image.save_webp(OUT + "/" + label + ".webp", false, 0.88) == OK, label + " actual rendering captured")
	game.set_physics_process(true)

func _walk(target: Vector2) -> void:
	for step: int in range(1600):
		player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		var delta: Vector2 = target - Vector2(player.position.x, player.position.z)
		if delta.length() < 0.22: break
		var direction: Vector2 = delta.normalized()
		_set_input(Vector2((direction.x-direction.y)*0.70710678, (direction.x+direction.y)*0.70710678))
		await physics_frame
	_set_input(Vector2.ZERO)
	await physics_frame
	_check(Vector2(player.position.x,player.position.z).distance_to(target) < 0.45 and player.position.y > -0.1, "Actual InputMap walk reaches " + str(target) + " at " + str(player.position))

func _set_input(value: Vector2) -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]: Input.action_release(action)
	if value.x < 0: Input.action_press(&"move_left", -value.x)
	if value.x > 0: Input.action_press(&"move_right", value.x)
	if value.y < 0: Input.action_press(&"move_forward", -value.y)
	if value.y > 0: Input.action_press(&"move_back", value.y)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ENV02 integration requires graphical rendering")
		quit(1)
		return
	root.size = Vector2i(1024,768)
	Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/world/greystone_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	player.movement.max_step_height = .18
	village = game.get_node("Village")
	(game.get_node("HUD") as CanvasLayer).visible = false
	await create_timer(.3).timeout
	snapshot = _snapshot()
	if record:
		if FileAccess.file_exists(BASELINE):
			push_error("Refusing to overwrite the pre-change baseline")
			quit(1)
			return
		snapshot.scene_sha256 = FileAccess.get_sha256("res://scenes/world/greystone_village.tscn")
		snapshot.source = "Pre-ENV02 replacement on feature/greystone-g06"
		FileAccess.open(BASELINE, FileAccess.WRITE).store_string(JSON.stringify(snapshot,"\t"))
		await _capture("before_waterwheel", Vector3(31,-.4,-4), 9)
		await _capture("before_farm", Vector3(-43,4.4,-46), 14)
		print("ENV02_BASELINE_RECORDED collisions=",snapshot.collisions.size())
		quit(0 if failures.is_empty() else 1)
		return
	baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) as Dictionary
	_check(not baseline.is_empty(), "Before-change baseline exists")
	for key: String in ["collisions","markers","buildings","protected"]:
		_check(snapshot[key] == baseline[key], "Replacement preserves " + key)
	var before_crops: Dictionary = baseline.placements.duplicate()
	var after_crops: Dictionary = snapshot.placements.duplicate()
	before_crops.erase("RiverWaterwheel")
	after_crops.erase("RiverWaterwheel")
	_check(before_crops == after_crops, "All crop transforms stay exact; only wheel relocated for visual clearance")
	var crop_count: int = 0
	var crop_mesh: Mesh
	var crop_triangles: int = 0
	for crop: Node3D in village.get_node("Props").get_children():
		if not String(crop.name).begins_with("Crop"): continue
		crop_count += 1
		_check(crop.scene_file_path == "res://scenes/world/greystone/props/leafy_crop.tscn", "Crop uses approved module")
		_check(crop.find_children("*","CollisionObject3D",true,false).is_empty(), "Crop retains decorative collision contract")
		var instance := crop.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		if crop_mesh == null: crop_mesh = instance.mesh
		_check(instance.mesh == crop_mesh, "Farm crops share one mesh")
		crop_triangles += _mesh_triangles(crop)
	_check(crop_count == 28 and crop_triangles == 4032, "28 crops and actual farm triangle total")
	var wheel := village.get_node("Props/RiverWaterwheel") as Node3D
	_check(wheel.scene_file_path == "res://scenes/world/greystone/props/waterwheel_bank.tscn", "River wheel uses bank mount module")
	_check(wheel.find_children("*","CollisionObject3D",true,false).is_empty(), "Wheel retains decorative collision contract")
	_check(_mesh_triangles(wheel) == 1372, "Waterwheel with fixed mount actual geometry budget")
	_check(wheel.position.is_equal_approx(Vector3(33.6,-1.35,-4)) and wheel.rotation.is_equal_approx(Vector3.ZERO), "Reviewed river placement")
	var wheel_bounds: AABB = _bounds(wheel)
	_check(wheel_bounds.position.x > 29.5, "Thicker axle stays clear of x=28m bank walking corridor")
	var materials: Dictionary = {}
	for child: Node in wheel.find_children("*","MeshInstance3D",true,false):
		var mesh := (child as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null and material.albedo_texture == null, "Wheel mount has no large textures")
			_check(material != null and material.resource_path in ["res://assets/materials/greystone/props/wood.tres", "res://assets/materials/greystone/props/iron.tres", "res://assets/materials/greystone/props/stone.tres"], "Wheel mount uses shared G04 palette")
			if material != null: materials[material.resource_path] = true
	_check(materials.size() == 3, "Wheel and support share exactly three materials")
	var pivot: Node3D = wheel.get("wheel")
	var moving_bounds: AABB = _bounds(pivot)
	var rock_bounds: AABB = _bounds(village.get_node("Terrain/RiverRock3"))
	_check(not moving_bounds.intersects(rock_bounds), "Moving wheel has no bounding overlap with river rock")
	var water_level: float = _bounds(village.get_node("Water/River")).position.y
	_check(absf(moving_bounds.position.y-water_level+0.1) < .025, "Paddles dip 0.10m into actual water surface")
	var support := wheel.find_child("BankSupport",true,false) as Node3D
	_check(support != null, "Fixed riverbed support exists")
	var support_transform: Transform3D = support.global_transform
	_check(_bounds(support).position.y < water_level-.2, "Support feet extend below water")
	var support_mesh := support as MeshInstance3D
	var closest_support_x: float = INF
	for surface: int in range(support_mesh.mesh.get_surface_count()):
		# Wide stone feet sit below the water and below the wheel. This check
		# concerns the A-frame timbers, not that separate foundation surface.
		var material := support_mesh.get_active_material(surface) as StandardMaterial3D
		if material.resource_path != "res://assets/materials/greystone/props/wood.tres": continue
		var points: PackedVector3Array = support_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in points:
			closest_support_x = minf(closest_support_x,absf((support_mesh.global_transform*point).x-wheel.global_position.x))
	var moving_half_x: float = maxf(absf(moving_bounds.position.x-wheel.global_position.x),absf(moving_bounds.end.x-wheel.global_position.x))
	_check(closest_support_x < INF and closest_support_x-moving_half_x > .1, "A-frame timbers stay outside rotating wheel width")
	var angle: float = pivot.rotation.x
	await create_timer(.6).timeout
	_check(absf(angle_difference(angle,pivot.rotation.x)) > .3, "Placed wheel rotates in the real scene")
	_check(support.global_transform.is_equal_approx(support_transform), "Only wheel rotates; support stays fixed")
	for marker: Node3D in village.get_node("ActivitySpaces").get_children():
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = .8
		query.shape = sphere
		query.transform.origin = marker.global_position + Vector3(0,1.1,0)
		query.exclude = [player.get_rid()]
		_check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "NPC forecourt clear: " + String(marker.name))
	# Existing movement component and InputMap; simulation is explicit, not
	# physical keyboard/controller certification. Use normal 60Hz movement.
	for point: Vector2 in [Vector2(0,40),Vector2(0,10),Vector2(-10,10),Vector2(-12,-10),Vector2(-12,-27),Vector2(-28,-27),Vector2(-42,-29),Vector2(-34,-29),Vector2(-34,-40),Vector2(-34,-46),Vector2(-34,-40),Vector2(-34,-29),Vector2(-42,-29)]:
		await _walk(point)
	_check(absf(player.position.y-4) < .2, "Farm approach remains supported at 4m")
	await _capture("after_farm", Vector3(-43,4.4,-46), 14)
	for point: Vector2 in [Vector2(-28,-27),Vector2(-12,-27),Vector2(-12,-10),Vector2(-10,10),Vector2(27,10),Vector2(28,10),Vector2(28,-4),Vector2(28,-8),Vector2(27,-8),Vector2(20,-8),Vector2(27,-8),Vector2(28,-8),Vector2(28,-4)]:
		await _walk(point)
	await _capture("after_waterwheel_a", Vector3(32.5,-.4,-4), 10)
	await create_timer(.5).timeout
	await _capture("after_waterwheel_b", Vector3(32.5,-.4,-4), 10)
	measurements = {"crop_instances":crop_count,"crop_triangles":crop_triangles,"wheel_triangles":_mesh_triangles(wheel),"wheel_bounds":str(wheel_bounds),"collision_shapes":snapshot.collisions.size(),"fixed_timber_clearance_x":closest_support_x-moving_half_x,"wheel_shared_materials":materials.keys()}
	var report: Dictionary = {"checks":checks,"failures":failures,"measurements":measurements,
		"scene_before_sha256":baseline.scene_sha256,"scene_after_sha256":FileAccess.get_sha256("res://scenes/world/greystone_village.tscn"),
		"graphical":true,"movement":"Actual InputMap / ExplorationPlayer at normal physics rate; synthetic input", "physical_input":false,
		"full_prologue":false,"performance_benchmark":false,"protected_files":snapshot.protected}
	FileAccess.open(OUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ENV02_VILLAGE_RESULT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
