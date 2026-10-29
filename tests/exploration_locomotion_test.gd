extends "res://tests/phase5_prologue_test.gd"
## Native rendered input + imported animation + real village collision acceptance.
var measurements: Dictionary = {"routes": [], "gaits": {}}
const OUT: String = "res://artifacts/locomotion/acceptance"
var output_path: String = OUT

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_integration.tscn").instantiate()

func _gait_actor(character: String) -> CartoonActor:
	return load("res://scenes/characters/%s_pixal_visual.tscn" % character).instantiate()

func _idle_restored() -> bool:
	return not game.player.appearance.get("animation_player").is_playing()

func _gait_clip(_character: String, base: StringName) -> StringName:
	return base

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_path)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.unfocusable = true # Automated input must not depend on desktop focus stealing.
	Engine.max_fps = 60
	var legacy: ExplorationPlayer = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(legacy)
	_check(not legacy.movement.running_enabled and legacy.movement.speed == 4.5, "Legacy controller retains original movement")
	_check(is_equal_approx((legacy.get_node("CollisionShape3D").shape as CapsuleShape3D).height, 1.6), "Legacy collision resource remains 1.6 m")
	legacy.queue_free()
	game = _create_game()
	DirAccess.make_dir_recursive_absolute("user://locomotion")
	(game.get_node("Saves") as SaveManager).slot_path = "user://locomotion/acceptance_%d.json" % Time.get_ticks_usec()
	root.add_child(game)
	await create_timer(.9).timeout
	await _finish_dialogue()
	_check(game.ready_to_play and not game.locked(), "Current G06 entry loads and releases opening dialogue")
	_check(game.player.appearance.scale == Vector3.ONE, "Ren exploration and battle use the same model scale")
	_check(is_equal_approx((game.player.get_node("CollisionShape3D").shape as CapsuleShape3D).height, 1.95), "Collision matches new visual height")
	_check(is_equal_approx(game.get("occlusion").target_height, 1.95), "Mine beam visibility follows new head height")
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.keycode = KEY_SHIFT
	key.shift_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await process_frame
	_check(game.player.input_component.read_run(), "Physical Shift binding requests run")
	game.player.input_component.enabled = false
	_check(not game.player.input_component.read_run(), "Dialogue/menu input lock blocks run")
	game.player.input_component.enabled = true
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not game.player.input_component.read_run(), "Unfocused window blocks run")
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var key_release: InputEventKey = key.duplicate()
	key_release.pressed = false
	key_release.shift_pressed = false
	Input.parse_input_event(key_release)
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_LEFT_SHOULDER
	joy.pressed = true
	# The developer panel is now hidden by default. Establish a real visible
	# background focus target before asserting LB cannot cycle it.
	await _tap(KEY_F10)
	var background_button: Button = game.get("bridge_button")
	background_button.grab_focus()
	await process_frame
	var prior_focus: Control = root.gui_get_focus_owner()
	_check(background_button.is_visible_in_tree() and not background_button.disabled and prior_focus == background_button, "Visible background button owns focus before LB regression")
	Input.parse_input_event(joy)
	await process_frame
	_check(game.player.input_component.read_run(), "Xbox LB binding requests run (injected input, not hardware certification)")
	_check(root.gui_get_focus_owner() == prior_focus, "Running with LB does not cycle background UI focus")
	var joy_release: InputEventJoypadButton = joy.duplicate()
	joy_release.pressed = false
	Input.parse_input_event(joy_release)
	await process_frame
	_check(not game.player.input_component.read_run(), "Releasing LB restores walking")
	await _tap(KEY_F10)
	joy.button_index = JOY_BUTTON_LEFT_STICK
	Input.parse_input_event(joy)
	await process_frame
	_check(not game.player.input_component.read_run(), "Pressing LS no longer requests running")
	joy_release = joy.duplicate()
	joy_release.pressed = false
	Input.parse_input_event(joy_release)
	for character: String in ["ren", "lia"]:
		await _gaits(character)
	for running: bool in [false, true]:
		await _place(Vector3(4, .1, 18))
		var start: Vector3 = game.player.position
		for frame: int in range(60):
			_direction(Vector2.RIGHT, running)
			await physics_frame
		var travel: float = Vector2(game.player.position.x - start.x, game.player.position.z - start.z).length()
		_release()
		var expected: float = 4.5 if running else 1.8
		_check(absf(travel - expected) < .18, "One-second %s travels %.3f m (target %.1f)" % ["run" if running else "walk", travel, expected])
		measurements["run_distance_m" if running else "walk_distance_m"] = travel
		await create_timer(.3).timeout
		_check(game.player.velocity.length() < .01 and _idle_restored(), "Release stops movement and restores idle")
	await _place(Vector3(4, .1, 18))
	_direction(Vector2(1, 1).normalized(), true)
	await create_timer(.2).timeout
	_check(Vector2(game.player.velocity.x, game.player.velocity.z).length() <= 4.501, "Diagonal run does not exceed speed cap")
	_release()
	var routes: Array = [
		{"name": "inn_walk", "start": Vector3(-10, .1, -10), "points": [Vector2(-20, -11), Vector2(-10, -10)], "run": false},
		{"name": "farm_run", "start": Vector3(-12, 1.1, -27), "points": [Vector2(-28, -27), Vector2(-42, -29), Vector2(-28, -27)], "run": true},
		{"name": "mine_walk_run", "start": Vector3(24, .1, -28), "points": [Vector2(24, -44), Vector2(24, -52), Vector2(24, -44)], "run": true}
	]
	for route: Dictionary in routes:
		await _place(route.start)
		for point: Vector2 in route.points:
			var reached: bool = await _walk_to(point, route.run)
			_check(reached, "Actual village %s reaches %s" % [route.name, point])
			if not reached: break
		_release()
		await create_timer(.3).timeout
		_check(game.player.is_on_floor() and game.player.velocity.length() < .01, "Elevated stop is grounded: " + route.name)
		await _capture_at(route.name)
	await _stairs()
	# Save/load uses the same strict capsule query; no schema or coordinates are rewritten.
	await _place(Vector3(4, .1, 18))
	var before: Dictionary = game.capture_state()
	_check(game.saves.request_save(), "Current strict codec saves safe position")
	_check(await game.saves.request_load(), "Current strict codec reloads with taller capsule")
	var after: Dictionary = game.capture_state()
	for field: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
		_check(before[field] == after[field], "Locomotion save/load preserves " + field)
	game.ui.set_input_hint(false)
	_check(game.ui.footer.text.contains("Shift"), "Keyboard footer explains run")
	game.ui.set_input_hint(true)
	_check(game.ui.footer.text.contains("LB"), "Gamepad footer explains run")
	await _capture_at("village_gameplay")
	measurements["checks"] = checks
	measurements["failures"] = failures
	measurements["renderer"] = DisplayServer.get_name()
	measurements["engine"] = Engine.get_version_info().string
	FileAccess.open(output_path + "/result.json", FileAccess.WRITE).store_string(JSON.stringify(measurements, "\t"))
	print("EXPLORATION_LOCOMOTION_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _direction(world: Vector2, running: bool) -> void:
	_release()
	var right: Vector3 = game.camera.global_basis.x
	var back: Vector3 = game.camera.global_basis.z
	right.y = 0
	back.y = 0
	right = right.normalized()
	back = back.normalized()
	var input: Vector2 = Vector2(world.dot(Vector2(right.x, right.z)), world.dot(Vector2(back.x, back.z)))
	Input.action_press(&"move_right" if input.x > 0 else &"move_left", absf(input.x))
	Input.action_press(&"move_back" if input.y > 0 else &"move_forward", absf(input.y))
	if running: Input.action_press(&"move_run")
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)

func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"move_run"]:
		Input.action_release(action)

func _walk_to(target: Vector2, running: bool) -> bool:
	var best: float = INF
	var stall: int = 0
	var frames: int = 0
	var grounded: int = 0
	var finite: bool = true
	for frame: int in range(1600):
		var difference: Vector2 = target - Vector2(game.player.position.x, game.player.position.z)
		if difference.length() < .18: break
		if difference.length() < best - .015:
			best = difference.length()
			stall = 0
		else: stall += 1
		if stall > 90: break
		_direction(difference.normalized(), running)
		await physics_frame
		frames += 1
		if game.player.is_on_floor(): grounded += 1
		var rig: Skeleton3D = game.player.appearance.get("skeleton")
		for bone: int in range(rig.get_bone_count()): finite = finite and rig.get_bone_global_pose(bone).is_finite()
	_release()
	_check(finite and frames > 0 and grounded >= frames * .95, "Route has finite bones and grounded collision")
	measurements.routes.append({"target": str(target), "run": running, "frames": frames, "grounded": grounded, "end": str(game.player.position)})
	return Vector2(game.player.position.x, game.player.position.z).distance_to(target) < .2

func _gaits(character: String) -> void:
	var actor: CartoonActor = _gait_actor(character)
	game.add_child(actor)
	actor.position = Vector3(4, 0, 18)
	actor.set_process(false)
	var rig: Skeleton3D = actor.get("skeleton")
	var clips: AnimationPlayer = actor.get("animation_player")
	for clip: StringName in [&"walk", &"run"]:
		var minimum: float = INF
		var maximum: float = -INF
		var forward_min: float = INF
		var forward_max: float = -INF
		actor.set_motion(.4 if clip == &"walk" else 1)
		actor.call("set_travel_speed", 1.8 if clip == &"walk" else 4.5)
		for frame: int in range(90):
			actor._process(1.0 / 60)
			var left: Vector3 = rig.get_bone_global_pose(rig.find_bone("FootLeft")).origin
			var right: Vector3 = rig.get_bone_global_pose(rig.find_bone("FootRight")).origin
			if frame > 20:
				minimum = minf(minimum, absf(left.x - right.x))
				maximum = maxf(maximum, absf(left.x - right.x))
				forward_min = minf(forward_min, left.z)
				forward_max = maxf(forward_max, left.z)
		_check(clips.current_animation == _gait_clip(character, clip), character + " selects actual " + clip)
		_check(minimum > .23 and maximum < .29, character + " narrows foot track without crossing: " + clip)
		_check(forward_max - forward_min > (.3 if clip == &"walk" else .6), character + " real fore-aft leg motion: " + clip)
		measurements.gaits[character + "_" + clip] = {"foot_span_min_m": minimum, "foot_span_max_m": maximum, "forward_stride_m": forward_max - forward_min, "rate": actor.get("last_motion_rate")}
	actor.queue_free()
	await process_frame

func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _stairs() -> void:
	var fixture: Node3D = Node3D.new()
	game.add_child(fixture)
	_box(fixture, Vector3(200, -.1, 0), Vector3(12, .2, 12))
	for step: int in range(3):
		var height: float = .12 * (step + 1)
		_box(fixture, Vector3(200, height * .5, -step), Vector3(3, height, 1))
	for running: bool in [false, true]:
		await _place(Vector3(200, .1, 2))
		_check(await _walk_to(Vector2(200, -2), running), "12 cm stairs traversed while " + ("running" if running else "walking"))
		_check(game.player.position.y > .34, "Stair solver reaches upper landing")
	_box(fixture, Vector3(204, .5, 0), Vector3(3, 1, .4))
	await _place(Vector3(204, .1, 2))
	for frame: int in range(45):
		_direction(Vector2(0, -1), true)
		await physics_frame
	_release()
	_check(game.player.position.z > .45 and game.player.position.y < .05, "Running cannot climb a one-metre wall")
	_box(fixture, Vector3(197, 1.85, 0), Vector3(2, .2, 2))
	await _place(Vector3(197, .1, 2))
	for frame: int in range(45):
		_direction(Vector2(0, -1), true)
		await physics_frame
	_release()
	_check(game.player.position.z > 1.25, "Taller head capsule cannot enter a 1.75 m ceiling")
	fixture.queue_free()

func _capture_at(label: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(910, 512, Image.INTERPOLATE_LANCZOS)
	image.save_webp(output_path + "/" + label + ".webp")
