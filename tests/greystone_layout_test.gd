extends SceneTree
var game: Node3D
var player: ExplorationPlayer
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("%s %s" % ["PASS" if value else "FAIL", title])

func _run() -> void:
	game = load("res://scenes/world/greystone_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	Engine.physics_ticks_per_second = 180
	Engine.time_scale = 6.0
	await create_timer(1.0).timeout
	_check(player.is_on_floor(), "Entrance has supporting collision")
	var start: Vector3 = player.position
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(1.0).timeout
	key = InputEventKey.new()
	key.physical_keycode = KEY_W
	Input.parse_input_event(key)
	_check(player.position.distance_to(start) > 2.0, "Actual W input moves existing player")
	for point: Vector2 in [Vector2(0,40),Vector2(0,16),Vector2(-6,10),Vector2(-23,6),Vector2(-10,6),Vector2(-10,-10),Vector2(-20,-11),Vector2(-10,-10),Vector2(0,-18),Vector2(0,-22),Vector2(12,-22),Vector2(12,-28),Vector2(24,-28),Vector2(24,-52),Vector2(24,-28),Vector2(42,-28),Vector2(24,-28),Vector2(27,-28),Vector2(27,-8),Vector2(20,-8),Vector2(27,-8),Vector2(27,10),Vector2(0,10),Vector2(-53,10),Vector2(0,10),Vector2(0,29),Vector2(-19,29),Vector2(19,29),Vector2(24,32),Vector2(32,32),Vector2(24,32)]:
		await _walk(point)
	await _walk(Vector2(28,10))
	await _walk(Vector2(34,10), false, 100)
	_check(player.position.x < 29.7 and player.position.y > -0.1, "River barrier prevents falling into water")
	await _walk(Vector2(28,26))
	await _walk(Vector2(34,26), false, 80)
	_check(player.position.x < 29.7 and player.position.y > -0.1, "Bank remains sealed beside dock access")
	await _walk(Vector2(28,10))
	await _walk(Vector2(20,10))
	await _walk(Vector2(20,0))
	await _walk(Vector2(20,-14), false, 150)
	_check(player.position.z > -10.5, "Shop wall blocks player")
	await _walk(Vector2(20,0))
	await _walk(Vector2(8,6))
	Engine.time_scale = 1.0
	await _capture("01-plaza")
	game.set_physics_process(false)
	game.camera.position = Vector3(90,127.28,90)
	game.camera.size = 155.0
	await _capture("02-layout")
	print("GREYSTONE_RESULT checks=%d failures=%d renderer=%s" % [checks,failures,DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _walk(target: Vector2, expect_reach: bool = true, frames: int = 1000) -> void:
	player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for unused: int in range(frames):
		var delta: Vector2 = target - Vector2(player.position.x,player.position.z)
		if delta.length() < 0.3:
			break
		var d: Vector2 = delta.normalized()
		var stick: Vector2 = Vector2((d.x-d.y)*0.70710678,(d.x+d.y)*0.70710678)
		_set_input(stick)
		await physics_frame
	_set_input(Vector2.ZERO)
	await physics_frame
	if expect_reach:
		_check(Vector2(player.position.x,player.position.z).distance_to(target) < 0.5 and player.position.y > -0.1,"Walk to %s" % target)

func _set_input(stick: Vector2) -> void:
	for action: String in ["move_left","move_right","move_forward","move_back"]:
		Input.action_release(action)
	if stick.x < 0: Input.action_press("move_left",-stick.x)
	if stick.x > 0: Input.action_press("move_right",stick.x)
	if stick.y < 0: Input.action_press("move_forward",-stick.y)
	if stick.y > 0: Input.action_press("move_back",stick.y)

func _capture(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/greystone-g01")
	var result: Error = root.get_texture().get_image().save_webp("res://artifacts/greystone-g01/%s.webp" % title)
	_check(result == OK,"Capture " + title)
