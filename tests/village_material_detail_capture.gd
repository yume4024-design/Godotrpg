extends "res://tests/phase5_prologue_test.gd"
## Actual candidate renderer, fixed before/after views. Not human acceptance.
func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1920,1080)
	root.content_scale_size = Vector2i(1280,720)
	root.unfocusable = true
	var label: String = "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var output: String = "res://artifacts/village_materials_20261109/"+label+"/"
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://village_material_detail/isolated.json"
	root.add_child(game)
	await create_timer(1).timeout
	if not game.ready_to_play:
		push_error("Candidate failed initialization")
		quit(1)
		return
	await _finish_dialogue()
	await _place(Vector3(-9,3.1,-8))
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(output+"gameplay.webp",false,.94)
	game.get_node("CameraRig").set_physics_process(false)
	game.player.set_physics_process(false)
	game.set_physics_process(false)
	for layer: Node in game.find_children("*", "CanvasLayer",true,false):
		(layer as CanvasLayer).visible = false
	var views: Dictionary = {
		"inn": [Vector3(-22,24,4), Vector3(-9,6,-16),25.0],
		"inn_close": [Vector3(-18,12,-3), Vector3(-10,5.8,-17),12.0],
		"shop": [Vector3(-30,15,7), Vector3(-21,5.4,-7),17.0],
		"weapon": [Vector3(3,16,20), Vector3(13,5.8,5),19.0],
		"plaza": [Vector3(-14,21,22), Vector3(0,3,-1),32.0]
	}
	var metrics: Dictionary = {}
	for view_name: String in views:
		var setup: Array = views[view_name]
		game.camera.global_position = setup[0]
		game.camera.look_at(setup[1])
		game.camera.size = setup[2]
		await physics_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(output+view_name+".webp",false,.95)
		var timings: Array[float] = []
		var last: int = Time.get_ticks_usec()
		var calls: int = 0
		# Warm after readback; exclude screenshot stall from sample.
		for warm: int in 10: await RenderingServer.frame_post_draw
		last = Time.get_ticks_usec()
		for sample: int in 120:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			timings.append((now-last)/1000.0)
			last=now
			calls=maxi(calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		timings.sort()
		var total: float = 0
		for ms: float in timings: total+=ms
		metrics[view_name]={"mean_ms":total/120.0,"p95_ms":timings[113],"p99_ms":timings[118],"draw_max":calls}
	var sources: Dictionary = {}
	for path: String in ["scenes/world/greystone/reference_v5/buildings.tscn","assets/models/greystone/reference_v5/terrain.glb","assets/models/greystone/reference_v5/paths.glb","assets/collisions/greystone/reference_v5/bounds.tscn","scenes/main/main.tscn","scripts/world/reference_village_surfaces.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	FileAccess.open(output+"metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"views":metrics,"sources":sources,"resolution":[1920,1080],"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"method":"120 frame_post_draw intervals/view; cap60; native editor binary; no endurance or GPU timing"},"  "))
	print("MATERIAL_CAPTURE_COMPLETE ",label," 6 actual candidate views")
	game.queue_free()
	await process_frame
	quit(0)
