extends SceneTree
## Native shader / water motion review, plus collision identity with treatment off.
const OUTPUT: String = "res://artifacts/greystone_surface_20261023/"
const WORLD: PackedScene = preload("res://scenes/world/greystone_blender_master.tscn")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed: failures.append(label)
	print("PASS " if passed else "FAIL ", label)

func _collision_signature(world: Node) -> String:
	var rows: Array[String] = []
	for node: Node in world.find_children("*", "CollisionShape3D", true, false):
		var collider: CollisionShape3D = node as CollisionShape3D
		var geometry: Variant
		if collider.shape is BoxShape3D: geometry = collider.shape.size
		elif collider.shape is ConvexPolygonShape3D: geometry = hash(collider.shape.points)
		elif collider.shape is ConcavePolygonShape3D: geometry = hash(collider.shape.get_faces())
		else: geometry = collider.shape.get_class()
		var body: CollisionObject3D = collider.get_parent() as CollisionObject3D
		# Generated collision node names use a process-global counter; compare
		# actual physics, including duplicate shapes, rather than those names.
		rows.append(collider.shape.get_class() + str(collider.global_transform) + str(geometry) + str(collider.disabled) + str(body.collision_layer) + str(body.collision_mask))
	rows.sort()
	return str(rows).sha256_text()

func _snapshot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT + name + ".png")
	return image

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_check(DisplayServer.get_name() != "headless", "Actual native graphical renderer")
	Engine.max_fps = 60
	var baseline: Node3D = WORLD.instantiate()
	var treatment: Node = baseline.get_node("SurfaceTreatment")
	baseline.remove_child(treatment)
	treatment.free()
	root.add_child(baseline)
	await physics_frame
	var original: String = _collision_signature(baseline)
	baseline.queue_free()
	await process_frame
	var preview: Node3D = load("res://scenes/tools/greystone_blender_preview.tscn").instantiate()
	root.add_child(preview)
	await physics_frame
	var village: Node3D = preview.get_node("Village")
	_check(original == _collision_signature(village), "Material treatment preserves every collision shape and transform")
	_check(village.get_node("Water").find_children("*", "CollisionShape3D", true, false).is_empty(), "Water and underwater beds introduce no walkable floor")
	var categories: Dictionary = {}
	var wood_surfaces: int = 0
	var wood_preserved: bool = true
	for node: Node in village.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.material_override is ShaderMaterial:
			categories[mesh.material_override.resource_path] = int(categories.get(mesh.material_override.resource_path, 0)) + 1
		for index: int in mesh.mesh.get_surface_count():
			var base: Material = mesh.mesh.surface_get_material(index)
			if base and ("_oak" in base.resource_name or "_timber" in base.resource_name):
				wood_surfaces += 1
				wood_preserved = wood_preserved and mesh.get_active_material(index) == base
	_check(wood_preserved and wood_surfaces > 10, "Existing oak and timber materials remain unchanged: " + str(wood_surfaces))
	_check(categories.size() == 6, "Six shared surface resources serve grass, soil, rock, river, lake and waterfall")
	preview.set_physics_process(false)
	preview.get_node("Player").visible = false
	preview.get_node("Player").set_physics_process(false)
	preview.get_node("HUD").visible = false
	var camera: Camera3D = preview.get_node("Camera3D")
	var views: Dictionary = {
		"overview": [Vector3(0,2,-8),115.0],
		"plaza": [Vector3(-3,4,2),17.0],
		"bridge": [Vector3(25,3,-29),20.0],
		"mine": [Vector3(0,10.3,-43),17.0],
		"dock": [Vector3(22,3,17),20.0],
		"rock_detail": [Vector3(21,1,-10),11.0]
	}
	var metrics: Dictionary = {}
	for label: String in views:
		var center: Vector3 = views[label][0]
		camera.position = center + Vector3(40,98,113)
		camera.look_at(center)
		camera.size = views[label][1]
		for settle: int in 30: await process_frame
		await _snapshot(label)
		var times: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		var calls: int = 0
		for sample: int in 120:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			times.append((now - previous) / 1000.0)
			previous = now
			calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		times.sort()
		var total: float = 0
		for value: float in times: total += value
		metrics[label] = {"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[113],"p99_ms":times[118],"max_ms":times.back(),"draw_calls_max":calls,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	camera.position = Vector3(25,3,-29) + Vector3(40,98,113)
	camera.look_at(Vector3(25,3,-29)); camera.size = 20
	for settle: int in 30: await process_frame
	var first: Image = await _snapshot("water_time_0")
	await create_timer(1.25).timeout
	var second: Image = await _snapshot("water_time_1")
	var changed: int = 0
	var samples: int = 0
	for y: int in range(0, first.get_height(), 3):
		for x: int in range(0, first.get_width(), 3):
			var a: Color = first.get_pixel(x,y)
			var b: Color = second.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.015: changed += 1
			samples += 1
	_check(changed > 1000, "Water changes across real rendered time with camera and actors static: " + str(changed) + "/" + str(samples))
	var report: Dictionary = {"checks":checks,"failures":failures,"collision_signature":original,"shared_materials":categories,"moving_samples":changed,"sample_count":samples,"renderer":RenderingServer.get_video_adapter_name(),"method":"120 frame_post_draw CPU intervals per fixed camera; 60 FPS cap. Not GPU duration, endurance, human input or mobile acceptance.","views":metrics}
	var file := FileAccess.open(OUTPUT + "result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("BLENDER_SURFACE_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
