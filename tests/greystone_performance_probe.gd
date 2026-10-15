extends "res://tests/phase5_prologue_test.gd"
## Diagnostic only: real renderer, isolated save, no production quality changes.
var samples: Array[Dictionary] = []

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Performance probe requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("user://g07_probe")
	var start_us: int = Time.get_ticks_usec()
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://g07_probe/unused.json"
	(game.get_node("Audio") as AdventureAudio).settings_path = "user://g07_probe/audio.cfg"
	root.add_child(game)
	for attempt: int in range(300):
		if game.ready_to_play and is_instance_valid(game.travel.current_map): break
		await process_frame
	if not game.ready_to_play or not is_instance_valid(game.travel.current_map):
		push_error("Village initialization timed out")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var first_frame_ms: float = (Time.get_ticks_usec() - start_us) / 1000.0
	await create_timer(.5).timeout
	await _finish_dialogue()
	_check(not game.dialogue.active and game.flags.has_flag(&"e001_done"), "Opening completed before exploration sampling")
	_check(game.ready_to_play and game.travel.current_map.map_id == &"greystone_runtime", "Real integrated village ready")
	var points: Dictionary = {
		"south": Vector3(0, .1, 48), "plaza": Vector3(6, .1, 6),
		"inn": Vector3(-20, 1.6, -11), "guild": Vector3(0, .1, -22),
		"farm": Vector3(-39, 4.1, -30), "mine": Vector3(24, 6.1, -49)}
	DirAccess.make_dir_recursive_absolute("res://artifacts/performance")
	for label: String in points:
		game.player.reset_to(points[label])
		await create_timer(.6).timeout
		_check(game.player.is_on_floor(), "Grounded probe: " + label)
		await _sample(label)
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_webp("res://artifacts/performance/" + label + ".webp") == OK, "Capture: " + label)
	var report: Dictionary = {
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": [1280,720], "camera_size": game.camera.size,
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"debug_build": OS.is_debug_build(), "android_verified": false,
		"first_frame_ms": first_frame_ms, "samples": samples,
		"inventory": _inventory(), "failures": failures,
		"method": "Six stationary views; 0.6s warmup then 2s wall-clock frame sampling each. No movement/cold-cache/mobile certification. Memory is engine static allocation, not process RSS."}
	var file: FileAccess = FileAccess.open("res://artifacts/performance/greystone_baseline.json", FileAccess.WRITE)
	_check(file != null, "Report writable")
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("G07_PROBE_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _sample(label: String) -> void:
	var frames: Array[float] = []
	var draws: float = 0.0
	var primitives: float = 0.0
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec() - start < 2000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - previous) / 1000.0)
		previous = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	frames.sort()
	var row: Dictionary = {"view": label, "frames": frames.size(), "fps": frames.size() / elapsed,
		"p95_frame_ms": frames[mini(frames.size()-1, int(ceil(frames.size()*.95))-1)],
		"mean_draw_calls": draws / frames.size(), "mean_render_primitives": primitives / frames.size(),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	samples.append(row)
	print(JSON.stringify(row))

func _inventory() -> Dictionary:
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var instances: int = 0
	var triangles: int = 0
	for node: Node in game.travel.current_map.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh == null: continue
		instances += 1
		meshes[instance.mesh.get_instance_id()] = true
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var primitive: int = (instance.mesh as ArrayMesh).surface_get_primitive_type(surface) if instance.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			if primitive == Mesh.PRIMITIVE_TRIANGLES:
				var count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
				triangles += count / 3
			var material: Material = instance.get_active_material(surface)
			if material != null: materials[material.get_instance_id()] = true
	return {"mesh_instances": instances, "unique_meshes": meshes.size(), "unique_active_materials": materials.size(),
		"instanced_triangles_all_map": triangles,
		"collision_shapes": game.travel.current_map.find_children("*", "CollisionShape3D", true, false).size()}
