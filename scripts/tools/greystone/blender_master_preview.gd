extends Node3D
## Isolated Blender import / physics candidate, never writes RPG state.
@onready var village: Node3D = $Village
@onready var player: ExplorationPlayer = $Player
@onready var camera: Camera3D = $Camera3D
var overview: bool = true
var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	# The imported world owns its geometry adapter, also used by RPG/save validation.
	var old: CartoonActor = player.appearance
	player.visual.remove_child(old)
	old.queue_free()
	player.appearance = preload("res://scenes/characters/ren_pixal_visual.tscn").instantiate()
	player.visual.add_child(player.appearance)
	# Match G06's actual 1.95 m character collider, not player.tscn's legacy default.
	var body_shape: CollisionShape3D = player.get_node("CollisionShape3D")
	body_shape.shape = body_shape.shape.duplicate()
	(body_shape.shape as CapsuleShape3D).height = 1.95
	body_shape.position.y = 0.975
	player.movement_camera = camera
	player.movement.max_step_height = 0.18
	player.movement.running_enabled = true
	player.movement.speed = 1.8
	player.movement.run_speed = 4.5
	player.reset_to(Vector3(-7, 0.4, 35))
	_update_camera()
	if "--blender-master-test" in OS.get_cmdline_user_args():
		get_window().unfocusable = true
		for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventJoypadMotion: InputMap.action_erase_event(action, event)
		_run_checks.call_deferred()
	elif "--blender-master-capture" in OS.get_cmdline_user_args():
		get_window().unfocusable = true
		_capture_views.call_deferred()

func _physics_process(_delta: float) -> void:
	if not overview: _update_camera()
	if player.position.y < -12: player.reset_to(Vector3(-7, 0.4, 35))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):
		overview = not overview
		_update_camera()

func _update_camera() -> void:
	var target: Vector3 = Vector3(0, 2, -8) if overview else player.position + Vector3.UP
	camera.position = target + Vector3(40, 98, 113)
	camera.look_at(target)
	camera.size = 115.0 if overview else 17.0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func _capture_views() -> void:
	Engine.max_fps = 60
	var measurements: Dictionary = {}
	for frame: int in 30: await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/greystone_blender_20261023/godot_overview.png")
	var views: Dictionary = {
		"plaza": Vector3(-3, 3.3, 2),
		"inn": Vector3(-10, 3.3, -8),
		"bridge": Vector3(20, 6.3, -29),
		"mine": Vector3(0, 10.3, -43),
		"dock": Vector3(20, 3.3, 16)
	}
	for label: String in views:
		player.reset_to(views[label])
		overview = false
		for frame: int in 20: await get_tree().physics_frame
		_update_camera()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/greystone_blender_20261023/godot_" + label + ".png")
		var timings: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		var calls: int = 0
		for sample: int in 120:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			timings.append((now - previous) / 1000.0)
			previous = now
			calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		timings.sort()
		var total: float = 0
		for value: float in timings: total += value
		measurements[label] = {"frames":timings.size(), "mean_ms":total / timings.size(), "p95_ms":timings[113], "p99_ms":timings[118], "max_draw_calls":calls, "static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC), "render_video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var report := FileAccess.open("res://artifacts/greystone_blender_20261023/capture_metrics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"method":"120 frame_post_draw intervals per static camera, Engine.max_fps=60; CPU scheduling intervals, not GPU timings, endurance or Android acceptance", "fps_cap":60, "views":measurements}, "  "))
	print("BLENDER_MASTER_CAPTURE_COMPLETE")
	get_tree().quit()

func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"move_run"]: Input.action_release(action)

func _walk(target: Vector3, frame_limit: int = 900) -> bool:
	for frame: int in frame_limit:
		player.input_component._window_focused = true
		var delta: Vector3 = target - player.position
		delta.y = 0
		if delta.length() < 0.4:
			_release()
			for settle: int in 10: await get_tree().physics_frame
			return player.is_on_floor() and absf(player.position.y - target.y) < 0.6
		var right: Vector3 = camera.global_basis.x
		var back: Vector3 = camera.global_basis.z
		right.y = 0; back.y = 0
		var direction := Vector2(delta.normalized().dot(right.normalized()), delta.normalized().dot(back.normalized()))
		_release()
		Input.action_press("move_right" if direction.x > 0 else "move_left", absf(direction.x))
		Input.action_press("move_back" if direction.y > 0 else "move_forward", absf(direction.y))
		Input.action_press("move_run")
		if frame == 30:
			print("BODY_STATE ", player.global_transform, " delta=", get_physics_process_delta_time(), " shape=", player.get_node("CollisionShape3D").global_transform, " engine=", ProjectSettings.get_setting("physics/3d/physics_engine"))
			print("MOVE_DIAGNOSTIC ", direction, " input=", player.input_component.read_direction(), " focused=", player.input_component._window_focused, " velocity=", player.velocity, " camera=", camera.global_basis)
			for index: int in player.get_slide_collision_count():
				var hit: KinematicCollision3D = player.get_slide_collision(index)
				print("CONTACT ", hit.get_collider().get_path(), " normal=", hit.get_normal(), " position=", hit.get_position())
		await get_tree().physics_frame
	_release()
	print("STALLED ", player.position, " target ", target)
	return false

func _run_checks() -> void:
	for frame: int in 30: await get_tree().physics_frame
	_check(DisplayServer.get_name() != "headless", "Native graphical renderer")
	_check(is_equal_approx((player.get_node("CollisionShape3D").shape as CapsuleShape3D).height, 1.95), "Actual G06 character collider height")
	_check(village.get_child_count() == 9, "Nine independently exported Blender collections including collision bounds")
	_check(village.get_node("Bounds").find_children("*", "MeshInstance3D", true, false).is_empty(), "Collision-only Blender guards have no visible mesh")
	_check(village.get_node("Bounds").find_children("*Body*", "StaticBody3D", true, false).size() == 7, "Seven simplified building bodies")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/greystone_blender_20261023/godot_overview.png")
	var routes: Dictionary = {
		"entry": [Vector3(-7,0.4,35), Vector3(-7,0,29), Vector3(-7,3,23), Vector3(-3,3,12), Vector3(-3,3,2)],
		"inn": [Vector3(-3,3.4,2), Vector3(-5,3,-7), Vector3(-10,3,-10)],
		"west": [Vector3(-3,3.4,0), Vector3(-27,3,-1), Vector3(-33,5,-1)],
		"bridge": [Vector3(20,6.4,-29), Vector3(34,6,-29)],
		"dock": [Vector3(12,3.4,13), Vector3(23,3,17)],
		"mine": [Vector3(8,6.4,-29), Vector3(3,6,-36), Vector3(0,10,-43)],
		"item_shop": [Vector3(-12,3.4,-2), Vector3(-20,3,-4.5)],
		"weapon_shop": [Vector3(6,3.4,3), Vector3(7,3,10), Vector3(13,3,9)],
		"west_house": [Vector3(-6,3.4,8), Vector3(-8,3,18), Vector3(-15,3,16)],
		"guild": [Vector3(0,3.4,-3), Vector3(4,3,-8), Vector3(9,3,-12)],
		"south_house": [Vector3(0,3.4,14), Vector3(0,3,21), Vector3(5,3,21)],
		"farm_house": [Vector3(-26,3.4,-1), Vector3(-26,3,-14), Vector3(-19,3,-19), Vector3(-24.5,6,-26), Vector3(-24,6,-28), Vector3(-20,6,-28), Vector3(-17,6,-29)]
	}
	for site: String in routes:
		var points: Array = routes[site]
		player.reset_to(points[0])
		for settle: int in 15: await get_tree().physics_frame
		for target: Vector3 in points.slice(1):
			var passed: bool = await _walk(target)
			_check(passed, site + " " + str(target))
			if not passed: break
	for obstacle: Array in [
		["west_cliff", Vector3(-44,5.4,-3), Vector3(-53,5,-3)],
		["river_bank", Vector3(19,3.4,-2), Vector3(28,3,-2)],
		["inn_wall", Vector3(-10,3.4,-10), Vector3(-10,3,-15)],
		["bridge_rail", Vector3(27,6.4,-29), Vector3(27,6,-36)],
		["dock_rim", Vector3(23,3.4,17), Vector3(30,3,17)]
	]:
		player.reset_to(obstacle[1])
		for settle: int in 15: await get_tree().physics_frame
		var reached: bool = await _walk(obstacle[2], 180)
		_check(not reached and player.is_on_floor() and absf(player.position.y - obstacle[1].y) < 0.8, str(obstacle[0]) + " blocks movement safely at " + str(player.position))
	var report: Dictionary = {"checks":checks,"failures":failures,"scope":"Native candidate entrances, routes and sampled obstacles; RPG and terrain-boundary gates run separately"}
	var file := FileAccess.open("res://artifacts/greystone_blender_20261023/route_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("BLENDER_MASTER_RESULT ", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
