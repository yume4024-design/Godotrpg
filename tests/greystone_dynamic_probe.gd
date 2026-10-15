extends "res://tests/greystone_performance_probe.gd"
func _initialize() -> void:
	report_filename = "greystone_dynamic.json"
	sampling_method = "Six sites, two seconds of actual InputMap movement each, baseline and temporary >45m mesh hiding. Reposition between trials. Static allocation is not RSS. CPU monitor values are sampled diagnostics, not per-frame timings."
	super._initialize()
## Diagnostic-only moving samples and reversible distance-culling experiment.
func _sample(label: String) -> void:
	var baseline: Dictionary = game.capture_state()
	var origin: Vector3 = game.player.position
	for culled: bool in [false, true]:
		game.player.reset_to(origin)
		await create_timer(.4).timeout
		var hidden: Array[MeshInstance3D] = []
		if culled:
			for node: Node in game.travel.current_map.find_children("*", "MeshInstance3D", true, false):
				var mesh: MeshInstance3D = node
				if mesh.visible and mesh.global_position.distance_to(game.player.global_position) > 45:
					hidden.append(mesh)
					mesh.hide()
		await create_timer(.2).timeout
		game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.action_press(&"move_right")
		var frames: Array[float] = []
		var draws: Array[float] = []
		var cpu: float = 0
		var physics: float = 0
		var memory_peak: float = 0
		var start: int = Time.get_ticks_usec()
		var previous: int = start
		while Time.get_ticks_usec() - start < 2000000:
			await process_frame
			var now: int = Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			cpu += Performance.get_monitor(Performance.TIME_PROCESS)*1000
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
			memory_peak = maxf(memory_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
		Input.action_release(&"move_right")
		var distance: float = game.player.position.distance_to(origin)
		_check(distance > .5, "Actual input movement: " + label)
		frames.sort()
		draws.sort()
		var row: Dictionary = {"view":label,"culled":culled,"hidden_meshes":hidden.size(),"distance_m":distance,"frames":frames.size(),"mean_frame_ms":frames.reduce(func(a:float,b:float)->float:return a+b,0.0)/frames.size(),"p95_frame_ms":frames[int(frames.size()*.95)],"max_frame_ms":frames[-1],"mean_process_ms":cpu/frames.size(),"mean_physics_ms":physics/frames.size(),"draw_calls_min":draws[0],"draw_calls_max":draws[-1],"static_peak_bytes":memory_peak,"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
		samples.append(row)
		print(JSON.stringify(row))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/performance/dynamic_%s_%s.webp" % [label,str(culled)])
		for mesh: MeshInstance3D in hidden: mesh.show()
	var after: Dictionary = game.capture_state()
	for key: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(baseline[key] == after[key], "Sampling preserves " + key)
