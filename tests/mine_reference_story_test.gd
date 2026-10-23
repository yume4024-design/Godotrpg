extends "res://tests/blender_village_story_test.gd"
var held: Dictionary = {}
const KEYS: Dictionary = {KEY_A:&"move_left",KEY_D:&"move_right",KEY_W:&"move_forward",KEY_S:&"move_back"}

func _initialize() -> void:
	super._initialize()
	slot = "user://mine_reference_tests/story.json"
	visual_slot = "user://mine_reference_tests/story_visual.json"
	DirAccess.make_dir_recursive_absolute("user://mine_reference_tests")
	root.unfocusable = true
	physics_frame.connect(_maintain_keyboard)

func _maintain_keyboard() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for key: int in KEYS:
		if held.get(key,false): Input.action_press(KEYS[key])
		else: Input.action_release(KEYS[key])

func _key(key: int,pressed: bool) -> void:
	if KEYS.has(key): held[key]=pressed
	super._key(key,pressed)

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/mine_reference_integration.tscn").instantiate() as ExplorationGame

func _mine_position(point: Vector3) -> Vector3:
	if point.x < 0: return Vector3(-44,.1,28)
	return Vector3(36,.1,39)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp("user://mine_reference_tests/"+label+".webp")==OK,"Mine graphical evidence "+label)

func _finish() -> void:
	var result: Dictionary = {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"mode":"reload" if "--reload" in OS.get_cmdline_user_args() else "prologue"}
	FileAccess.open("user://mine_reference_tests/story_result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("MINE_STORY_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
