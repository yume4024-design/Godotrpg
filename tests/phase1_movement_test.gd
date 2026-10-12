extends SceneTree
## Real physics integration checks: use the project Input Map and main scene.
## Run with tools/godot.ps1 -Mode Test. No test addon is required.

var failures: int = 0
var player: CharacterBody3D
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var main: Node3D = scene.instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player") as CharacterBody3D
	camera = main.get_node("CameraRig/Camera3D") as Camera3D
	await _frames(45)
	_check(player.is_on_floor() and absf(player.position.y) < 0.02, "Player settles on floor")
	var original_basis: Basis = camera.global_basis
	var start: Vector3 = player.position
	await _frames(60)
	_check(player.position.distance_to(start) < 0.005, "Idle player remains stable")

	# Physical keys exercise the actual Input Map, not a duplicate direction function.
	for key: int in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		await _reset(Vector3(0, 0.05, 6))
		start = player.position
		_key(key, true)
		await _frames(20)
		_key(key, false)
		var displacement: Vector3 = player.position - start
		var screen_right: float = displacement.dot(camera.global_basis.x)
		var screen_up: float = displacement.dot(camera.global_basis.y)
		var correct: bool = displacement.length() > 1.2
		if key in [KEY_W, KEY_UP]:
			correct = correct and screen_up > 0.5 and absf(screen_right) < 0.05
		elif key in [KEY_S, KEY_DOWN]:
			correct = correct and screen_up < -0.5 and absf(screen_right) < 0.05
		elif key in [KEY_A, KEY_LEFT]:
			correct = correct and screen_right < -1.0 and absf(screen_up) < 0.05
		else:
			correct = correct and screen_right > 1.0 and absf(screen_up) < 0.05
		_check(correct, "Camera-relative key %s" % OS.get_keycode_string(key))
		await _frames(2)
		start = player.position
		await _frames(10)
		_check(player.position.distance_to(start) < 0.005, "Release stops %s" % OS.get_keycode_string(key))

	await _reset(Vector3(0, 0.05, 6))
	start = player.position
	_key(KEY_W, true)
	await _frames(30)
	_key(KEY_W, false)
	var cardinal_distance: float = player.position.distance_to(start)
	await _reset(Vector3(0, 0.05, 6))
	start = player.position
	_key(KEY_W, true)
	_key(KEY_D, true)
	await _frames(30)
	_key(KEY_W, false)
	_key(KEY_D, false)
	var diagonal_distance: float = player.position.distance_to(start)
	_check(absf(cardinal_distance - diagonal_distance) < 0.1, "Diagonal speed equals cardinal speed")

	await _reset(Vector3(2.8, 0.05, 2.0))
	_key(KEY_W, true)
	_key(KEY_D, true)
	await _frames(120)
	_key(KEY_W, false)
	_key(KEY_D, false)
	_check(player.position.z > 0.60 and player.position.z < 0.68, "Stone blocks sustained movement")
	_check(player.is_on_floor(), "Stone contact does not lift player off floor")

	await _reset(Vector3(10, 0.05, 8))
	_key(KEY_S, true)
	_key(KEY_D, true)
	await _frames(120)
	_key(KEY_S, false)
	_key(KEY_D, false)
	_check(player.position.x > 11.30 and player.position.x < 11.40, "Boundary prevents leaving the ground")
	_check(camera.global_basis.is_equal_approx(original_basis), "Camera angle stays fixed")

	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(30)
	_check(player.position.distance_to(Vector3(0, 0, 4)) < 0.03, "R returns player to spawn")
	print("PHASE1_RESULT failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
	await process_frame


func _reset(position: Vector3) -> void:
	player.call("reset_to", position)
	await _frames(15)


func _key(code: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label + " position=" + str(player.position))
