extends "res://tests/greystone_performance_probe.gd"

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Quality comparison needs real rendering")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://g07_quality_unused.json"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	game.player.reset_to(Vector3(0,.1,-22))
	await create_timer(.3).timeout
	var quality: ExplorationQuality = game.get("quality")
	var button: Button = game.get("quality_button")
	var before: Dictionary = game.capture_state()
	_check(quality.preset == ExplorationQuality.Preset.HIGH and root.msaa_3d == Viewport.MSAA_4X, "Default high preserves existing MSAA")
	_check(not quality.apply(-1) and not quality.apply(3), "Unknown presets rejected")
	DirAccess.make_dir_recursive_absolute("res://artifacts/performance/quality")
	for preset: int in [0,1,2]:
		await _click_quality(button)
		_check(quality.preset == preset, "Rendered button selects preset %d" % preset)
		_check((game.get_node("Sun") as DirectionalLight3D).shadow_enabled == (preset != 0), "Shadow toggle applied")
		_check(is_equal_approx((game.get_node("Sun") as DirectionalLight3D).directional_shadow_max_distance, 30.0 if preset == 1 else 60.0), "Shadow distance applied")
		_check(root.msaa_3d == preset, "MSAA applied")
		await create_timer(.6).timeout
		await _sample(str(preset))
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_webp("res://artifacts/performance/quality/%d.webp" % preset) == OK, "Quality screenshot")
	for field: String in ["party","inventory","flags","quests","rewards"]:
		_check(before[field] == game.capture_state()[field], "Preset preserves " + field)
	_check(game.player.global_position.distance_to(Vector3(0,0,-22)) < .2, "Preset preserves grounded position")
	root.size = Vector2i(960,540)
	await create_timer(.2).timeout
	await _click_quality(button)
	_check(quality.preset == 0, "Small window button remains usable")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/performance/quality/small.webp")
	(game.get("mobile_input") as MobileInputLayer).set_enabled(true)
	for pressed: bool in [true,false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 1
		touch.position = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * .5))
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
		await physics_frame
	_check(quality.preset == 1, "Touch switches shared quality button")
	var file: FileAccess = FileAccess.open("res://artifacts/performance/quality/results.json",FileAccess.WRITE)
	_check(file != null, "Quality report writable")
	if file != null:
		file.store_string(JSON.stringify({"samples":samples,"failures":failures,"android_verified":false},"\t"))
		file.close()
	print("G07_QUALITY_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _click_quality(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * (button.size * .5))
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await physics_frame
