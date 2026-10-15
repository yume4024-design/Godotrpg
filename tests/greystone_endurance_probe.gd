extends "res://tests/greystone_performance_probe.gd"

func _initialize() -> void:
	report_filename = "greystone_endurance.json"
	sampling_method = "Six sites, 20 seconds of alternating InputMap movement each (120 seconds sampled), normal high quality. Reset between sites; no distance culling. Static allocation includes measurement arrays and is not RSS."
	super._initialize()

func _sample(label: String) -> void:
	var baseline: Dictionary = game.capture_state()
	var frames: Array[float] = []
	var memory: Array[float] = []
	var draws_min: float = INF
	var draws_max: float = 0
	var slow: int = 0
	var distance: float = 0
	var previous_position: Vector3 = game.player.position
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var second: int = -1
	while Time.get_ticks_usec() - start < 20000000:
		var elapsed: int = int((Time.get_ticks_usec() - start) / 1000000)
		if elapsed != second:
			second = elapsed
			memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
			game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			Input.action_release(&"move_left")
			Input.action_release(&"move_right")
			Input.action_press(&"move_right" if second % 2 == 0 else &"move_left")
		await process_frame
		var now: int = Time.get_ticks_usec()
		var frame_ms: float = (now - previous) / 1000.0
		frames.append(frame_ms)
		if frame_ms > 16.667: slow += 1
		previous = now
		distance += game.player.position.distance_to(previous_position)
		previous_position = game.player.position
		var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draws_min = minf(draws_min, draws)
		draws_max = maxf(draws_max, draws)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	frames.sort()
	var row: Dictionary = {"view":label,"distance_m":distance,"frames":frames.size(),"mean_ms":frames.reduce(func(a:float,b:float)->float:return a+b,0.0)/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_ms":frames[-1],"over_16_667_ms":slow,"draw_min":draws_min,"draw_max":draws_max,"memory_first":memory[0],"memory_last":memory[-1],"memory_peak":memory.max(),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	samples.append(row)
	print(JSON.stringify(row))
	_check(distance > 20, "Sustained movement: " + label)
	_check(row.p95_ms < 16.667, "Desktop sample P95 within 60 FPS budget: " + label)
	var after: Dictionary = game.capture_state()
	for key: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(baseline[key] == after[key], "State preserved: " + key)
