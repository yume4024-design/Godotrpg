extends "res://tests/phase5_prologue_test.gd"
## Native, real-controller integration with a frozen pre-replacement physics baseline.
const OUT: String = "res://artifacts/env02_mine_integration"
const BASELINE: String = "res://source_assets/environment_rebuild_20261022/mine_support_integration/baseline.json"
const PROTECTED: Array[String] = [
	"res://scenes/main/main.tscn", "res://scenes/world/mine.tscn",
	"res://scripts/world/expanded_wilderness.gd", "res://scripts/world/scene_manager.gd",
	"res://scripts/world/exploration_occlusion.gd", "res://scripts/core/greystone_integration.gd",
	"res://scripts/save/save_codec.gd", "res://data/story/prologue_events.json",
	"res://data/quests/q001.json"
]
var region: ExplorationMap
var record: bool = false
var details: Dictionary = {}

func _snapshot() -> Dictionary:
	var result: Dictionary = {"collisions": [], "targets": {}, "markers": {}, "protected": {}}
	# Node-generated numeric names can change with instantiation order. Compare the
	# complete sorted multiset of shapes/transforms/layers, preserving multiplicity.
	for node: Node in region.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as CollisionObject3D
		var shape: Shape3D = collision.shape
		var dimensions: Variant
		if shape is BoxShape3D: dimensions = (shape as BoxShape3D).size
		elif shape is CapsuleShape3D: dimensions = [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
		elif shape is SphereShape3D: dimensions = (shape as SphereShape3D).radius
		elif shape is CylinderShape3D: dimensions = [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
		else: _check(false, "Unhandled original shape: " + shape.get_class())
		result.collisions.append(var_to_bytes([collision.global_transform, shape.get_class(), dimensions, collision.disabled, body.collision_layer, body.collision_mask]).hex_encode())
	result.collisions.sort()
	for target: WorldInteractable in region.targets:
		result.targets[String(target.interaction_id)] = var_to_bytes([target.global_transform, target.kind, target.battle_id, target.required_flag, target.destination, target.spawn_key, target.reward_source]).hex_encode()
	for key: String in ["default_spawn", "entrance_spawn", "story_zone", "camera_zone", "opening_spawn", "return_spawn", "sequence_target", "sequence_light"]:
		var marker: Node3D = region.get(key) as Node3D
		result.markers[key] = var_to_bytes(marker.global_transform).hex_encode() if is_instance_valid(marker) else "none"
	for path: String in PROTECTED:
		_check(FileAccess.file_exists(path), "Protected source exists: " + path)
		result.protected[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	var occupancy: Array[bool] = []
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (game.player.get_node("CollisionShape3D") as CollisionShape3D).shape
	query.collision_mask = 1
	for x: int in range(-24, 25, 2):
		for z: int in range(-18, 19, 2):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.005, z))
			occupancy.append(not region.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())
	result.occupancy = occupancy
	return result

func _move_to(target: Vector2, running: bool) -> void:
	if running: Input.action_press(&"move_run")
	var contacts: Array[String] = []
	for step: int in range(500):
		game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var offset: Vector2 = target - Vector2(game.player.position.x, game.player.position.z)
		if offset.length() < .15: break
		var direction: Vector2 = offset.normalized()
		var stick := Vector2(direction.x-direction.y, direction.x+direction.y)*.70710678
		_release_movement(false)
		Input.action_press(&"move_right" if stick.x > 0 else &"move_left", absf(stick.x))
		Input.action_press(&"move_back" if stick.y > 0 else &"move_forward", absf(stick.y))
		await physics_frame
		for index: int in range(game.player.get_slide_collision_count()):
			var contact: KinematicCollision3D = game.player.get_slide_collision(index)
			var body := contact.get_collider() as Node3D
			if is_instance_valid(body) and not contacts.has(str(body.global_position)): contacts.append(str(body.global_position))
	_release_movement()
	await create_timer(.12).timeout
	var reached: bool = Vector2(game.player.position.x, game.player.position.z).distance_to(target) < .3
	if not details.has("routes"): details.routes = []
	details.routes.append({"target":str(target),"running":running,"actual":str(game.player.position),"reached":reached,"contacts":contacts,"locked":game.locked(),"on_floor":game.player.is_on_floor(),"velocity":str(game.player.velocity),"input_after_release":str(game.player.input_component.read_direction())})
	if not reached: print("ROUTE_DIAGNOSTIC ",JSON.stringify(details.routes[-1]))
	_check(reached, "Actual InputMap %s reaches %s" % ["run" if running else "walk", target])
	_check(game.player.is_on_floor() and game.player.velocity.length() < .01, "Actual controller stops grounded")

func _release_movement(include_run: bool = true) -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]: Input.action_release(action)
	if include_run: Input.action_release(&"move_run")

func _view(label: String, target: Vector3, span: float) -> void:
	game.set_physics_process(false)
	var original: Transform3D = game.camera.global_transform
	var size: float = game.camera.size
	var occlusion: ExplorationOcclusion = game.get("occlusion")
	var was_enabled: bool = occlusion.enabled
	occlusion.enabled = false
	game.camera.global_position = target + Vector3(12, 16.970563, 12)
	game.camera.look_at(target)
	game.camera.size = span
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(910, 512, Image.INTERPOLATE_LANCZOS)
	_check(picture.save_webp(OUT + "/" + label + ".webp", false, .9) == OK, label + " native viewport captured")
	game.camera.global_transform = original
	game.camera.size = size
	occlusion.enabled = was_enabled
	game.set_physics_process(true)

func _profile() -> Dictionary:
	game.set_physics_process(false)
	var original: Transform3D = game.camera.global_transform
	var size: float = game.camera.size
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
	var elapsed: float = times.reduce(func(total: float, value: float) -> float: return total+value, 0.0)
	times.sort()
	var result: Dictionary = {"frames": times.size(), "fps": times.size()*1000.0/elapsed, "mean_ms": elapsed/times.size(), "p95_ms": times[int(times.size()*.95)], "p99_ms": times[int(times.size()*.99)], "max_ms": times.max(), "draw_calls_min": draws.min(), "draw_calls_max": draws.max(), "engine_static_bytes_max": memory.max(), "fps_limit": Engine.max_fps, "camera": "fixed whole mine; short diagnostic only"}
	game.camera.global_transform = original
	game.camera.size = size
	game.set_physics_process(true)
	return result

func _replacement_checks() -> void:
	var supports: Node3D = region.get_node_or_null("MineSupports")
	_check(is_instance_valid(supports), "Eight imported supports replace primitive renderers")
	if not is_instance_valid(supports): return
	_check(supports.get_child_count() == 8, "Exactly eight support PackedScene instances")
	_check(supports.find_children("*", "CollisionShape3D", true, false).is_empty(), "Visual adapter adds no second collision set")
	var resources: Dictionary = {}
	var materials: Dictionary = {}
	var triangles: int = 0
	var occluders: Array[MeshInstance3D] = []
	for child: Node3D in supports.get_children():
		var beam := child.get_node(String(child.get_meta("beam_node"))) as MeshInstance3D
		_check(beam.is_in_group(&"exploration_occluder"), "Imported beam registered: " + String(child.name))
		occluders.append(beam)
		for node: Node in child.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			resources[mesh.mesh.get_instance_id()] = true
			for surface: int in range(mesh.mesh.get_surface_count()):
				triangles += mesh.mesh.surface_get_array_index_len(surface)/3
				materials[mesh.mesh.surface_get_material(surface).resource_path] = true
	_check(resources.size() == 3 and triangles == 6432, "Eight assemblies share three Mesh resources; 6432 triangles")
	_check(materials.size() == 3 and materials.has("res://assets/materials/greystone/props/wood.tres") and materials.has("res://assets/materials/greystone/props/wood_cut.tres") and materials.has("res://assets/materials/greystone/props/iron.tres"), "All placements share the existing three G04 materials")
	var occlusion: ExplorationOcclusion = game.get("occlusion")
	_check(occlusion.get("_meshes").size() == 11, "Existing three fixed and eight imported beams are the only occluders")
	for x: int in [-12,-4,4,12]:
		for side: int in [-1,1]:
			var lane: float = x + (1.2 if x < 0 else -1.2)
			# Avoid the original decorative crystal in the middle of each opening.
			await _place(Vector3(lane,.1,side*14))
			await _move_to(Vector2(lane,side*18), false)
			await _move_to(Vector2(lane,side*14), true)
	# A normal controller must still hit a retained timber post.
	await _place(Vector3(-14.2,.1,-14.5))
	Input.action_press(&"move_right", .70710678)
	Input.action_press(&"move_forward", .70710678)
	for step: int in range(90):
		game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await physics_frame
	_release_movement()
	_check(game.player.position.z > -15.6 and game.player.position.z < -15.3, "Original post stops actual player at capsule contact")
	# Probe the actual production occlusion rays with the real follow camera.
	await _place(Vector3(10.8,.1,15))
	await create_timer(.6).timeout
	var beam: MeshInstance3D = occluders[7]
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Imported beam hides when the production camera ray crosses the hero")
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUT + "/occlusion_active.webp", false,.9) == OK, "Actual follow-camera occlusion captured")
	await _place(Vector3(10.8,.1,13))
	await create_timer(.6).timeout
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Imported beam returns when player clears its camera ray")
	details.imported_triangles = triangles
	details.shared_meshes = resources.size()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Mine integration acceptance requires a native renderer")
		quit(1)
		return
	record = "--record-baseline" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	Engine.max_fps = 60
	# A connected controller can emit motion while scripted actions are held.
	# Isolate only this QA process's bindings; never change production InputMap.
	details.connected_controller_snapshot = preload("res://tests/qa_input_isolation.gd").isolate_joypad_motion()
	details.input_method = "InputMap actions with joypad-motion bindings removed in this QA process; not physical input acceptance"
	DirAccess.make_dir_recursive_absolute(OUT)
	_check(root.unfocusable, "Native test window does not request user focus")
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://env02_mine/session.json"
	root.add_child(game)
	for step: int in range(1200):
		if game.ready_to_play: break
		await process_frame
	await _wait_travel()
	await create_timer(.1).timeout
	_check(game.ready_to_play and game.resume_offer, "Existing completed isolated fixture offers Continue")
	var loaded: bool = await game.saves.request_load()
	_check(loaded, "Strict codec loads real completed G08 fixture")
	if not loaded:
		_finish()
		return
	_check(game.flags.has_flag(&"chapter_departure_done") and game.inventory.gold == 212 and game.party.member(&"lia").experience == 300, "Unaltered completed progression loaded")
	_check(game.travel.travel(&"mine"), "Existing SceneManager enters expanded mine")
	await _wait_travel()
	region = game.travel.current_map
	await physics_frame
	var snapshot: Dictionary = _snapshot()
	_check(snapshot.collisions.size() == 34 and snapshot.targets.size() == 4 and snapshot.occupancy.size() == 475, "Frozen scope includes 34 colliders, four interactions and 475 capsule probes")
	if record:
		_check(not FileAccess.file_exists(BASELINE) and not region.has_node("MineSupports"), "Refuse to overwrite original pre-replacement baseline")
		if failures == 0: FileAccess.open(BASELINE,FileAccess.WRITE).store_string(JSON.stringify(snapshot,"\t"))
	else:
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		for key: String in ["collisions", "targets", "markers", "protected", "occupancy"]:
			_check(snapshot[key] == baseline[key], "Visual replacement preserves " + key)
		await _replacement_checks()
		await _place(Vector3(10.8,.1,14))
		var before: Dictionary = game.capture_state()
		_check(game.saves.request_save(), "Existing safe mine lane saves through the unchanged codec")
		_check(await game.saves.request_load(), "Strict save reload reconstructs the imported supports")
		for key: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
			_check(before[key] == game.capture_state()[key], "Save/load preserves " + key)
		var invalid: Dictionary = game.capture_state().duplicate(true)
		invalid.location.x = -14.2
		invalid.location.z = -16.0
		var valid_slot: String = game.saves.slot_path
		game.saves.slot_path = "user://env02_mine/occupied.json"
		FileAccess.open(game.saves.slot_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
		var preserved: Dictionary = game.capture_state()
		_check(not await game.saves.request_load(), "Full load validation rejects an occupied timber position")
		_check(preserved == game.capture_state(), "Rejected occupied save leaves all current state intact")
		game.saves.slot_path = valid_slot
		region = game.travel.current_map
		await _place(Vector3(-10,.1,0))
		await _tap(KEY_E)
		await _wait_travel()
		_check(game.travel.current_map.map_id == &"forest", "Real E interaction exits mine into existing forest")
		await _place(Vector3(8.6,.1,2.2))
		await _tap(KEY_E)
		await _wait_travel()
		region = game.travel.current_map
		_check(region.map_id == &"mine" and region.has_node("MineSupports"), "Forest entrance recreates imported mine supports")
	await _place(Vector3(10.8,.1,14))
	await _view(("before_" if record else "after_")+"frame", Vector3(12,1,16),8)
	await _view(("before_" if record else "after_")+"map", Vector3.ZERO,60)
	details.profile = await _profile()
	details.engine = Engine.get_version_info().string
	details.renderer = DisplayServer.get_name()
	details.checks = checks
	details.failures = failures
	details.baseline = record
	FileAccess.open(OUT + ("/before_result.json" if record else "/result.json"),FileAccess.WRITE).store_string(JSON.stringify(details,"\t"))
	print("ENV02_MINE_INTEGRATION_RESULT checks=%d failures=%d baseline=%s" % [checks,failures,record])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
