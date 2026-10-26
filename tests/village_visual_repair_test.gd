extends "res://tests/phase5_prologue_test.gd"
## Native gameplay captures of reported visual defects; baseline is observation only.
func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.unfocusable = true
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var architecture_only: bool = "--architecture-only" in OS.get_cmdline_user_args()
	game = load("res://scenes/main/mine_reference_integration.tscn" if baseline else "res://scenes/main/greystone_reference_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://village_visual_repair/isolated.json"
	root.add_child(game)
	await create_timer(1).timeout
	if not game.ready_to_play or not is_instance_valid(game.travel.current_map) or game.travel.current_map.get_node_or_null("Village") == null:
		push_error("Reference scene was not loaded; no valid visual evidence was produced.")
		quit(1)
		return
	await _finish_dialogue()
	var label: String = "before" if "--baseline" in OS.get_cmdline_user_args() else "after"
	var output: String = "res://artifacts/village_repair/"+label+"/"
	var measurements: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(output)
	var views: Dictionary = {
		"entry_base":Vector3(-7,.1,30.4),
		"entry_top":Vector3(-7,3.1,22),
		"north_steps":Vector3(-20,3.1,-17),
		"mine_approach":Vector3(8,6.1,-29),
		"mine_landing":Vector3(0,10.1,-43),
		"dock_road":Vector3(17,3.1,15),
		"boat":Vector3(25,3.1,18),
		"plaza":Vector3(-3,3.1,3),
		"inn_facade":Vector3(-9,3.1,-8),
		"item_facade":Vector3(-21,3.1,-1),
		"river_cliff":Vector3(39,3.1,-6)
	}
	for name: String in ([] if architecture_only else views.keys()):
		await _place(views[name])
		await physics_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(output+name+".webp",false,.92)
		var timings: Array[float] = []
		var last: int = Time.get_ticks_usec()
		var calls: int = 0
		for sample: int in 120:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			timings.append((now-last)/1000.0);last=now
			calls=maxi(calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		timings.sort()
		var total: float = 0
		for timing: float in timings:total+=timing
		measurements[name]={"mean_ms":total/120,"p95_ms":timings[113],"p99_ms":timings[118],"max_draw_calls":calls,"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	game.get_node("CameraRig").set_physics_process(false)
	game.set_physics_process(false)
	for layer: Node in game.find_children("*", "CanvasLayer",true,false): (layer as CanvasLayer).visible = false
	game.camera.far = 400
	game.camera.global_position = Vector3(20,103,92)
	game.camera.look_at(Vector3(0,3,-8))
	game.camera.size = 103
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(output+"overview.webp",false,.95)
	# HUD-free architectural review uses the same live map and renderer. The
	# player's close exploration camera and input settings remain unchanged.
	var architecture_views: Dictionary = {
		"inn_architecture": [Vector3(-22,24,4), Vector3(-9,6,-16), 25.0],
		"item_architecture": [Vector3(-30,15,7), Vector3(-21,5.4,-7), 17.0],
		"weapon_architecture": [Vector3(3,16,20), Vector3(13,5.8,5), 19.0],
		"south_cliff_detail": [Vector3(-29,17,38), Vector3(-17,0,26), 24.0],
		"north_cliff_detail": [Vector3(-22,20,-7), Vector3(-14,5,-27), 26.0],
		"mine_cliff_detail": [Vector3(13,28,-22), Vector3(6,13,-43), 34.0],
		"plaza_detail": [Vector3(-14,21,22), Vector3(0,3,-1), 32.0],
		"waterfall_detail": [Vector3(42,22,-17), Vector3(28,8,-39), 22.0]
	}
	for view_name: String in architecture_views:
		var setup: Array = architecture_views[view_name]
		game.camera.global_position = setup[0]
		game.camera.look_at(setup[1])
		game.camera.size = setup[2]
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(output+view_name+".webp",false,.95)
		if view_name == "waterfall_detail":
			await create_timer(.75).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp(output+"waterfall_motion.webp",false,.95)
	FileAccess.open(output+"metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"method":"120 native frame_post_draw intervals/view at 60 FPS cap, scheduler timing not GPU duration or endurance","renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"views":measurements},"  "))
	print("VILLAGE_VISUAL_CAPTURE ",label," ",(0 if architecture_only else views.size())+2+architecture_views.size()," actual rendered views; no human acceptance claimed")
	game.queue_free()
	await process_frame
	quit(0)
