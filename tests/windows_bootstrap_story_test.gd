extends "res://tests/greystone_story_test.gd"
## Run the existing full prologue against the actual game created by the loader.
## Only the ownership hook differs; every existing story/save/battle check runs.
const OUT: String = "res://artifacts/windows_bootstrap"
var boot: WindowsCandidateBootstrap
var loading_input_checked: bool = false
var captured_splash: bool = false

func _create_game() -> ExplorationGame:
	return boot.game as ExplorationGame

func _attach_game(instance: ExplorationGame) -> void:
	_check(instance.get_parent() == boot, "Full story uses the same game created by the loading screen")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Loading-screen acceptance requires native graphics")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(OUT)
	# Match the inherited story test's isolated slot lifecycle before boot.
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://crystal_g06_slot_01.json"+suffix): DirAccess.remove_absolute("user://crystal_g06_slot_01.json"+suffix)
	if "--reload" in OS.get_cmdline_user_args():
		_check(DirAccess.copy_absolute("user://g06_story_tests/visual.json","user://crystal_g06_slot_01.json") == OK, "Restart uses an exact copy of the real completed test save")
	boot = load("res://scenes/main/windows_candidate_bootstrap.tscn").instantiate()
	_check(Engine.max_fps == 60, "Native acceptance uses the same 60 FPS budget")
	boot.phase_changed.connect(_phase_observed)
	root.add_child(boot)
	var deadline: int = Time.get_ticks_usec()+30000000
	while boot.phase not in ["ready", "failed"] and Time.get_ticks_usec() < deadline: await process_frame
	_check(boot.phase == "ready", "Loading gate reaches ready")
	_check(captured_splash, "Splash was actually rendered before game load")
	_check(loading_input_checked, "Input was exercised while the loading screen covered the game")
	if boot.phase != "ready":
		quit(1)
		return
	await process_frame
	_check(boot.get_node_or_null("LoadingCanvas") == null, "Ready removes the loading overlay")
	FileAccess.open(OUT+"/timings.json",FileAccess.WRITE).store_string(JSON.stringify(boot.timings,"\t"))
	await super._run()

func _finish() -> void:
	FileAccess.open(OUT+("/reload_result.json" if "--reload" in OS.get_cmdline_user_args() else "/story_result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"same_game_from_bootstrap":true,"loading_input_checked":loading_input_checked},"\t"))
	print("BOOTSTRAP_STORY_RESULT checks=%d failures=%d" % [checks,failures])
	# Same delayed audio release as the real preview close handler; the inherited
	# bare-scene test teardown quits too early for this actual preview instance.
	boot.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures == 0 else 1)

func _phase_observed(value: String) -> void:
	if value == "splash_presented":
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		picture.resize(910,512,Image.INTERPOLATE_LANCZOS)
		captured_splash = picture.save_webp(OUT+"/loading.webp",false,.9) == OK
	if value == "preparing_picture":
		var instance := boot.game as ExplorationGame
		var line: int = instance.dialogue.line_index
		var reveals: Array[int] = [0]
		var reveal_observed: Callable = func() -> void: reveals[0] += 1
		instance.dialogue.reveal_requested.connect(reveal_observed)
		var position: Vector3 = instance.player.position
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.keycode = KEY_E
		key.pressed = true
		Input.parse_input_event(key)
		Input.action_press(&"move_forward")
		await physics_frame
		await physics_frame
		key.pressed = false
		Input.parse_input_event(key)
		Input.action_release(&"move_forward")
		instance.dialogue.reveal_requested.disconnect(reveal_observed)
		_check(instance.dialogue.line_index == line and reveals[0] == 0, "Loading E does not reveal/advance the underlying opening dialogue")
		_check(instance.player.position.distance_to(position) < .03, "Loading movement does not move the player")
		loading_input_checked = true
