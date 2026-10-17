extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Foot performance probe requires a graphical renderer")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var preview: Node3D = load("res://scenes/tools/lia_movement_preview.tscn").instantiate()
	root.add_child(preview)
	var player: ExplorationPlayer = preview.get("player")
	var original: LiaFootPlacement = preview.get("foot_placement")
	var parent: Node = original.get_parent()
	var measured: LiaFootPlacement = load("res://tests/measured_foot_placement.gd").new()
	measured.actor = original.actor
	measured.skeleton = original.skeleton
	measured.body = original.body
	measured.allow_motion = true
	measured.physics_pose = true
	parent.remove_child(original)
	original.queue_free()
	parent.add_child(measured)
	preview.set("foot_placement",measured)
	var rows: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute("res://artifacts/performance")
	for trial: int in range(4):
		_release()
		measured.enabled = trial%2==1
		(preview.find_child("FootPlacementToggle",true,false) as CheckBox).set_pressed_no_signal(measured.enabled)
		player.reset_to(Vector3(6,0,6))
		await create_timer(.6).timeout
		measured.call("start_profile")
		var frames: Array[float] = []
		var draw_min: float = INF
		var draw_max: float = 0
		var distance: float = 0
		var position: Vector3 = player.position
		var began: int = Time.get_ticks_usec()
		var previous: int = began
		while Time.get_ticks_usec()-began<4000000:
			var second: int = int((Time.get_ticks_usec()-began)/1000000)
			var direction: float = 1.0 if second%2==0 else -1.0
			_release()
			Input.action_press(&"move_right" if direction>0 else &"move_left",.70710678)
			Input.action_press(&"move_back" if direction>0 else &"move_forward",.70710678)
			player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			await process_frame
			var now: int = Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			previous = now
			distance += player.position.distance_to(position)
			position = player.position
			var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			draw_min = minf(draw_min,draws)
			draw_max = maxf(draw_max,draws)
		_release()
		frames.sort()
		var methods: Dictionary = measured.call("profile_report")
		var row: Dictionary = {"trial":trial,"enabled":measured.enabled,"distance_m":distance,"frames":frames.size(),"mean_frame_ms":frames.reduce(func(a:float,b:float)->float:return a+b,0.0)/frames.size(),"p95_frame_ms":frames[int(frames.size()*.95)],"max_frame_ms":frames[-1],"draw_min":draw_min,"draw_max":draw_max,"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"script_methods":methods}
		rows.append(row)
		print(JSON.stringify(row))
		_check(distance>12,"Actual movement during trial %d" % trial)
		_check(int(methods.combined_us.count)>120,"Physics method samples cover trial %d" % trial)
		_check(preview.find_child("Saves",true,false)==null,"Probe has no save service")
		if measured.enabled:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/performance/lia_foot_enabled.webp")
	var report: Dictionary = {"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"debug_build":OS.is_debug_build(),"rows":rows,"failures":failures,"android_verified":false,"method":"Four 4-second moving samples in real static Greystone village, alternating disabled/enabled. Uncapped graphical wall-clock frame intervals. Script timings wrap only component methods and exclude deferred skinning/render work; static memory is not RSS or a leak proof."}
	var file: FileAccess = FileAccess.open("res://artifacts/performance/lia_foot_placement.json",FileAccess.WRITE)
	_check(file!=null,"Performance report writable")
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	preview.queue_free()
	await process_frame
	print("LIA_FOOT_PROFILE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"move_forward",&"move_back"]: Input.action_release(action)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
