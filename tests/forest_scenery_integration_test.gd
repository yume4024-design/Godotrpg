extends "res://tests/phase5_prologue_test.gd"
## Rendered, additive ENV02 placement; collision/save contracts are compared to
## a frozen pre-change map, rather than trusting the new placement itself.

const OUT: String = "res://artifacts/env02_forest_integration"
const BASELINE: String = "res://source_assets/environment_rebuild_20261020/forest_integration/baseline.json"
const PROTECTED: Array[String] = ["res://scenes/main/main.tscn", "res://scenes/world/forest.tscn", "res://scripts/world/expanded_wilderness.gd", "res://scripts/save/save_codec.gd", "res://data/story/prologue_events.json"]
var region: ExplorationMap
var details: Dictionary = {}
var record: bool = false

func _snapshot() -> Dictionary:
	var result: Dictionary = {"collisions": {}, "targets": {}, "markers": {}, "protected": {}}
	for node: Node in region.find_children("*", "CollisionShape3D", true, false):
		if region.get_path_to(node).get_name(0) == &"Scenery": continue
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as CollisionObject3D
		var shape: Shape3D = collision.shape
		var dimensions: Variant
		if shape is BoxShape3D: dimensions = (shape as BoxShape3D).size
		elif shape is CapsuleShape3D: dimensions = [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
		elif shape is SphereShape3D: dimensions = (shape as SphereShape3D).radius
		elif shape is CylinderShape3D: dimensions = [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
		else: _check(false, "Unhandled pre-existing collision class " + shape.get_class())
		result.collisions[String(region.get_path_to(node))] = var_to_bytes([collision.global_transform, shape.get_class(), dimensions, collision.disabled, body.collision_layer, body.collision_mask]).hex_encode()
	for target: WorldInteractable in region.targets:
		result.targets[String(target.interaction_id)] = var_to_bytes([target.global_transform, target.kind, target.battle_id, target.required_flag]).hex_encode()
	for node: Node in region.find_children("*", "Marker3D", true, false):
		result.markers[String(region.get_path_to(node))] = var_to_bytes((node as Node3D).global_transform).hex_encode()
	for path: String in PROTECTED:
		result.protected[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	var occupancy: Array[bool] = []
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (game.player.get_node("CollisionShape3D") as CollisionShape3D).shape
	query.collision_mask = 1
	for x: int in range(-23, 24, 2):
		for z: int in range(-23, 24, 2):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.005, z))
			occupancy.append(not region.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())
	result.occupancy = occupancy
	return result

func _bounds(node: Node3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in vertices:
				var value: Vector3 = instance.global_transform * point
				low = low.min(value)
				high = high.max(value)
	return AABB(low, high-low)

func _view(label: String, target: Vector3, span: float) -> void:
	game.set_physics_process(false)
	var original: Transform3D = game.camera.global_transform
	var size: float = game.camera.size
	game.camera.global_position = target + Vector3(12, 16.970563, 12)
	game.camera.look_at(target)
	game.camera.size = span
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(910, 512, Image.INTERPOLATE_LANCZOS)
	_check(picture.save_webp(OUT + "/" + label + ".webp", false, 0.9) == OK, label + " captured from native viewport")
	game.camera.global_transform = original
	game.camera.size = size
	game.set_physics_process(true)

func _move_to(target: Vector2) -> void:
	Input.action_press(&"move_run")
	for step: int in range(500):
		game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var delta: Vector2 = target - Vector2(game.player.position.x, game.player.position.z)
		if delta.length() < .2: break
		var direction: Vector2 = delta.normalized()
		var stick: Vector2 = Vector2(direction.x-direction.y, direction.x+direction.y)*.70710678
		for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]: Input.action_release(action)
		Input.action_press(&"move_right" if stick.x > 0 else &"move_left", absf(stick.x))
		Input.action_press(&"move_back" if stick.y > 0 else &"move_forward", absf(stick.y))
		await physics_frame
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"move_run"]: Input.action_release(action)
	await create_timer(.12).timeout
	_check(Vector2(game.player.position.x, game.player.position.z).distance_to(target) < .4, "Actual InputMap route reaches " + str(target))
	_check(game.player.is_on_floor() and game.player.velocity.length() < .01, "Route ends grounded and stopped")

func _profile() -> Dictionary:
	game.set_physics_process(false)
	var original: Transform3D = game.camera.global_transform
	var original_size: float = game.camera.size
	game.camera.global_position = Vector3(32, 45.25483, 32)
	game.camera.look_at(Vector3.ZERO)
	game.camera.size = 60
	for step: int in range(30): await process_frame
	var times: Array[float] = []
	var draws: Array[float] = []
	var memory: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for step: int in range(300):
		await process_frame
		var current: int = Time.get_ticks_usec()
		times.append((current-previous)/1000.0)
		previous = current
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	times.sort()
	var result: Dictionary = {"frames": times.size(), "mean_ms": times.reduce(func(total: float, value: float) -> float: return total+value, 0.0)/times.size(), "p95_ms": times[int(times.size()*.95)], "p99_ms": times[int(times.size()*.99)], "draw_calls_min": draws.min(), "draw_calls_max": draws.max(), "engine_static_bytes_max": memory.max(), "camera": "fixed whole map", "fps_limit": Engine.max_fps}
	game.camera.global_transform = original
	game.camera.size = original_size
	game.set_physics_process(true)
	return result

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forest scenery acceptance requires a native graphical renderer")
		quit(1)
		return
	record = "--record-baseline" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://env02_forest_unused.json"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	game.saves.slot_path = "user://p5_tests/restart.json"
	_check(await game.saves.request_load(), "Real completed G06 prologue fixture loads")
	_check(game.flags.has_flag(&"chapter_departure_done") and game.party.members().size() == 2, "Fixture has exact completed progression and both characters")
	game.saves.slot_path = "user://env02_forest_acceptance.json"
	_check(game.travel.travel(&"forest"), "Existing SceneManager enters expanded forest")
	await _wait_travel()
	region = game.travel.current_map
	await physics_frame
	var snapshot: Dictionary = _snapshot()
	if record:
		_check(not FileAccess.file_exists(BASELINE), "Refuse to overwrite pre-change baseline")
		_check(not region.has_node("Scenery"), "Pre-change map has no added log scenery")
		if failures == 0:
			FileAccess.open(BASELINE, FileAccess.WRITE).store_string(JSON.stringify(snapshot, "\t"))
	else:
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		for key: String in ["collisions", "targets", "markers", "protected", "occupancy"]:
			_check(snapshot[key] == baseline[key], "Additive scenery preserves " + key)
		_check(snapshot.occupancy.size() == 576, "576 pre-existing capsule occupancy samples are unchanged")
		var scenery: Node3D = region.get_node("Scenery")
		var shared: Mesh
		var triangles: int = 0
		var placements: Array[Dictionary] = []
		for child: Node3D in scenery.get_node("Logs").get_children():
			var bounds: AABB = _bounds(child)
			_check(bounds.position.x > 24.8 or bounds.end.x < -24.8 or bounds.position.z > 24.8 or bounds.end.z < -24.8, "Full visible log stays outside original walkable walls: " + String(child.name))
			_check(bounds.position.x >= -28.3 and bounds.end.x <= 28.3 and bounds.position.z >= -28.3 and bounds.end.z <= 28.3, "Entire model has visual ground beneath it")
			var visual := child.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			if shared == null: shared = visual.mesh
			_check(shared == visual.mesh, "Log placements share the same imported Mesh")
			var count: int = 0
			for surface: int in range(visual.mesh.get_surface_count()): count += visual.mesh.surface_get_array_index_len(surface)/3
			triangles += count
			_check(count == 268, "Each placement retains the accepted 268 triangles")
			var collision := child.get_node("TrunkCollision/Shape") as CollisionShape3D
			_check(collision.shape is CapsuleShape3D and collision.scale == Vector3.ONE, "Placement retains simplified unscaled trunk capsule")
			var origin: Vector3 = collision.global_position
			var probe := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 2, 0), origin-Vector3(0, .3, 0), 1)
			var hit: Dictionary = region.get_world_3d().direct_space_state.intersect_ray(probe)
			_check(not hit.is_empty() and hit.get("collider") == child.get_node("TrunkCollision"), "Actual trunk collision remains active behind the traversal boundary")
			placements.append({"name": child.name, "bounds": str(bounds), "triangles": count})
		_check(placements.size() == 3 and triangles == 804, "Three instances cost 804 visible triangles, without duplicate models")
		details.placements = placements
		# Real controller movement along unchanged edge routes and the story path.
		for route: Dictionary in [{"start": Vector3(-21,.1,-14), "end": Vector2(-21,-18)}, {"start": Vector3(21,.1,7), "end": Vector2(21,11)}, {"start": Vector3(6,.1,21), "end": Vector2(10,21)}, {"start": Vector3(-7,.1,0), "end": Vector2(7,0)}]:
			await _place(route.start)
			await _move_to(route.end)
		# The new visuals must not make previously valid saves invalid.
		await _place(Vector3(-7,.1,0))
		var before: Dictionary = game.capture_state()
		_check(game.saves.request_save(), "Safe original forest position saves")
		_check(await game.saves.request_load(), "Same strict codec reloads forest with new scenery")
		for key: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
			_check(before[key] == game.capture_state()[key], "Save/load preserves " + key)
		var invalid: Dictionary = game.capture_state().duplicate(true)
		invalid.location.x = 26.8
		_check(game.saves.codec.prepare(invalid, game).is_empty(), "Scenery behind boundary does not expand valid save coordinates")
		_check(game.travel.travel(&"greystone_runtime"), "Forest returns through existing SceneManager")
		await _wait_travel()
		_check(game.travel.travel(&"forest"), "Forest reinstantiates after roundtrip")
		await _wait_travel()
		region = game.travel.current_map
		_check(region.has_node("Scenery/Logs/EastLog"), "Placed models survive scene recreation")
	for view: Dictionary in [{"name":"west_edge", "target": Vector3(-25,0,-14)}, {"name":"east_edge", "target": Vector3(25,0,9)}, {"name":"south_edge", "target":Vector3(8,0,25)}]:
		await _view(("before_" if record else "after_")+view.name, view.target, 10)
	await _view("before_map" if record else "after_map", Vector3.ZERO, 60)
	details.profile = await _profile()
	if not record:
		# Same-process A/B isolates the three shared logs and four ground strips.
		# It is a short overview sample, never a 30-minute/player certification.
		region.get_node("Scenery").visible = false
		details.hidden_scenery_profile = await _profile()
		region.get_node("Scenery").visible = true
	details.engine = Engine.get_version_info().string
	details.renderer = DisplayServer.get_name()
	details.checks = checks
	details.failures = failures
	FileAccess.open(OUT + ("/before_result.json" if record else "/result.json"), FileAccess.WRITE).store_string(JSON.stringify(details,"\t"))
	print("ENV02_FOREST_RESULT checks=%d failures=%d baseline=%s" % [checks, failures, record])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
