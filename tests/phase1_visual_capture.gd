extends SceneTree
## Development-only rendered evidence. Not referenced by the game or exported.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main/practice_main.tscn") as PackedScene
	var main: Node3D = packed.instantiate() as Node3D
	root.add_child(main)
	current_scene = main
	await create_timer(1.0).timeout
	await _capture("phase1-start.webp")
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.8).timeout
	event = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(0.2).timeout
	await _capture("phase1-moved.webp")
	main.get_node("Player").call("reset_to", Vector3(0, 0.1, 4))
	root.size = Vector2i(960, 540)
	await create_timer(0.5).timeout
	await _capture("phase1-960.webp")
	print("VISUAL_CAPTURE_COMPLETE")
	quit()


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var directory: String = ProjectSettings.globalize_path("res://artifacts/screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	var error: Error = frame.save_webp(directory.path_join(file_name), true)
	if error != OK:
		push_error("Screenshot failed: " + str(error))
		quit(1)
	print("CAPTURE: ", file_name, " ", frame.get_size())
