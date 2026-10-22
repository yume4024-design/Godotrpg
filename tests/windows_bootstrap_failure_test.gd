extends SceneTree
## Actual native error UI and focused exit button, with a deliberately missing
## scene or a deliberate startup deadline. No user save paths are involved.
var boot: WindowsCandidateBootstrap
var checks: int = 0
var failures: int = 0
var mode: String = "missing"
const OUT: String = "res://artifacts/windows_bootstrap"

func _initialize() -> void:
	if "--timeout" in OS.get_cmdline_user_args(): mode = "timeout"
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", message)

func _run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(1280,720)
	boot = load("res://scenes/main/windows_candidate_bootstrap.tscn").instantiate()
	if mode == "missing": boot.game_scene_path = "res://missing_startup_scene.tscn"
	else: boot.timeout_seconds = .001
	root.add_child(boot)
	var deadline: int = Time.get_ticks_usec()+10000000
	while boot.phase != "failed" and Time.get_ticks_usec() < deadline: await process_frame
	_check(boot.phase == "failed", "Deliberate " + mode + " failure shows error state")
	_check(boot.status.text.contains("重新開啟"), "Failure message is actionable and contains no internal path")
	_check(boot.exit_button.visible and boot.exit_button.has_focus(), "Error exit is visible and focused")
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(910,512,Image.INTERPOLATE_LANCZOS)
	_check(picture.save_webp(OUT+"/failure_"+mode+".webp",false,.9) == OK, "Native failure screen captured at 960x540")
	boot.exit_button.pressed.connect(_exit_observed)
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await create_timer(.5).timeout
	_check(false,"Focused error exit must receive the real UI action")
	quit(1)

func _exit_observed() -> void:
	_check(true,"Focused error exit received actual keyboard input")
	FileAccess.open(OUT+"/failure_"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"case":mode},"\t"))
	print("BOOTSTRAP_FAILURE_RESULT checks=%d failures=%d case=%s" % [checks,failures,mode])
	# Let the actual error button's delayed native shutdown run. The watchdog in
	# _run fails if that real handler never exits; the observer must not fake it.
	if failures != 0: quit(1)
