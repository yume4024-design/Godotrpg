extends "res://tests/phase5_prologue_test.gd"
## Actual rendered production scene, input-driven route, and P5 collision contract.

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute("user://village_art")
	game = load("res://scenes/main/main.tscn").instantiate() as ExplorationGame
	(game.get_node("Saves") as SaveManager).slot_path = "user://village_art/route.json"
	(game.get_node("Audio") as AdventureAudio).settings_path = "user://village_art/audio.cfg"
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://village_art/route.json" + suffix)
	root.add_child(game)
	await create_timer(0.8).timeout
	await _finish_dialogue()
	var village: ExplorationMap = game.travel.current_map
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/village_collision_v1.json"))
	_check(village.find_children("*", "CollisionShape3D", true, false).size() == baseline.collisions.size(), "No new or missing gameplay collisions")
	for row: Dictionary in baseline.collisions:
		var collider: CollisionShape3D = village.get_node(row.path) as CollisionShape3D
		var p: Array = row.position
		var s: Array = row.size
		_check(collider.global_position.is_equal_approx(Vector3(p[0], p[1], p[2])) and (collider.shape as BoxShape3D).size.is_equal_approx(Vector3(s[0], s[1], s[2])) and collider.global_basis.is_equal_approx(Basis.IDENTITY), "P5 collision preserved: " + str(row.path))
	await _capture("01-spawn")
	await _walk_to(Vector3(0, 0, -0.65))
	_check(game.nearest != null and game.nearest.interaction_id == &"npc_guildmaster", "Walked from spawn to guild prompt")
	await _capture("02-guild")
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e002_done"), "Guild interaction accepts Q001")
	await _walk_to(Vector3(3, 0, -1.6))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.party.member(&"lia") != null, "Walked to Lia and recruited through E003")
	await _walk_to(Vector3(3, 0, 1))
	await _walk_to(Vector3(5, 0, 5.8))
	await _capture("03-crystal-plaza")
	_check(await game.saves.request_save(), "Save at renovated plaza")
	var saved_position: Vector3 = game.player.position
	await _walk_to(Vector3(4, 0, 4))
	_check(await game.saves.request_load() and game.player.position.distance_to(saved_position) < 0.08, "Load plaza position through SaveCodec and live collision validation")
	await _walk_to(Vector3(8, 0, 3.2))
	await _walk_to(Vector3(8.7, 0, 0))
	await _capture("04-forest-bridge")
	_check(game.nearest != null and game.nearest.interaction_id == &"to_forest", "Walked to forest transition beside scenic bridge")
	# Test actual border response and the monument using analog input/physics.
	await _place(Vector3(10.6, 0.1, 5))
	await _walk_to(Vector3(13, 0, 5), false, 55)
	_check(game.player.position.x < 11.75, "River edge remains solid and cannot be walked into")
	await _place(Vector3(6, 0.1, 5.6))
	await _walk_to(Vector3(6, 0, 8), false, 45)
	_check(game.player.position.z < 6.7, "Crystal memorial retains solid original trunk footprint")
	await _place(Vector3(0, 0.1, 4))
	root.size = Vector2i(960, 540)
	await _capture("05-small-gameplay")
	root.size = Vector2i(1280, 720)
	# Overview is an evidence-only camera; normal gameplay captures stay at size 21.
	game.camera.get_parent().set_physics_process(false)
	game.set_physics_process(false)
	game.camera.get_parent().position = Vector3(0, 1, -1)
	game.camera.size = 45
	game.ui.visible = false
	await _capture("06-village-overview")
	game.ui.visible = true
	game.camera.get_parent().set_physics_process(true)
	game.set_physics_process(true)
	game.camera.size = game.travel.current_map.default_camera_size
	await create_timer(0.6).timeout
	if DisplayServer.get_name() != "headless":
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for unused: int in range(120):
			await process_frame
			var now: int = Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		print("VILLAGE_PROFILE median_ms=%.3f p95_ms=%.3f max_ms=%.3f draws=%d primitives=%d" % [samples[60], samples[114], samples[119], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	await _place(Vector3(8.7, 0.1, 0))
	await _tap(KEY_E)
	await create_timer(0.7).timeout
	_check(game.travel.current_map.map_id == &"forest", "Forest interaction still transitions successfully")
	print("VILLAGE_ART_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _walk_to(target: Vector3, should_reach: bool = true, frames: int = 145) -> void:
	for unused: int in range(frames):
		var delta: Vector3 = target - game.player.position
		delta.y = 0
		if delta.length() < 0.12: break
		var direction: Vector3 = delta.normalized()
		var stick: Vector2 = Vector2((direction.x-direction.z)*0.70710678, (direction.x+direction.z)*0.70710678)
		_analog(stick)
		await physics_frame
	_analog(Vector2.ZERO)
	await physics_frame
	await physics_frame
	if should_reach:
		_check(Vector2(game.player.position.x-target.x, game.player.position.z-target.z).length() < 0.2, "Input-driven route reaches " + str(target))

func _analog(value: Vector2) -> void:
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value.x if axis == JOY_AXIS_LEFT_X else value.y
		Input.parse_input_event(event)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/village-v2")
	var shot: Image = root.get_texture().get_image()
	_check(shot.save_webp("res://artifacts/village-v2/" + name + ".webp", true, 0.85) == OK, "Rendered " + name)
	shot.resize(roundi(shot.get_width() * 512.0 / shot.get_height()), 512, Image.INTERPOLATE_LANCZOS)
	shot.save_webp("res://artifacts/village-v2/" + name + "-review.webp", true, 0.8)
