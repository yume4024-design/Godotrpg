class_name G083StartupProbe
extends SceneTree
## Embedded diagnostic main loop in a separate RC3-source QA export.
## Reads actual production nodes/signals; never replaces gameplay methods or
## calls manager mutation APIs. Render signal intervals are wall time, not GPU
## timestamps. App-cache fresh does not imply a cold OS/driver cache.

var game: Node3D
var bootstrap: Node
var loading_screen: bool = false
var events: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var current_frame: Dictionary = {}
var began: int
var previous: int
var output: String = ""
var model_scene: String
var capture_done: bool = false
var map_seen: bool = false
var ended: bool = false
var errors: Array[String] = []
var stop_after_usec: int = 5000000

func _stamp(label: String) -> void:
	events.append({"event": label, "engine_usec": Time.get_ticks_usec(), "frame": Engine.get_process_frames()})

func _initialize() -> void:
	began = Time.get_ticks_usec()
	previous = began
	_stamp("script_initialize")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-output="): output = argument.trim_prefix("--probe-output=")
		if argument == "--loading-screen": loading_screen = true
		if argument == "--frame-cap=60": Engine.max_fps = 60
	if output.is_empty() or not output.is_absolute_path():
		push_error("An absolute --probe-output directory is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	model_scene = "res://scenes/main/greystone_preview.tscn"
	if not OS.has_feature("g083_startup") or OS.is_debug_build() or DisplayServer.get_name() == "headless":
		errors.append("Rendered isolated g083_startup release required")
	if model_scene != "res://scenes/main/greystone_preview.tscn":
		errors.append("Unexpected candidate entry " + model_scene)
	process_frame.connect(_frame_begin)
	RenderingServer.frame_pre_draw.connect(_draw_begin)
	RenderingServer.frame_post_draw.connect(_draw_end)
	_run.call_deferred()

func _frame_begin() -> void:
	if ended: return
	var now: int = Time.get_ticks_usec()
	current_frame = {"frame": Engine.get_process_frames(), "begin_usec": now, "interval_ms": (now-previous)/1000.0}
	previous = now
	frames.append(current_frame)
	if is_instance_valid(game):
		var travel: Node = game.get("travel") as Node
		if travel != null and is_instance_valid(travel.get("current_map")) and not map_seen:
			map_seen = true
			_stamp("map_observed")
			current_frame["map_id"] = str(travel.get("current_map").get("map_id"))
	elif is_instance_valid(bootstrap) and is_instance_valid(bootstrap.get("game")):
		game = bootstrap.get("game") as Node3D
	if now-began > stop_after_usec and frames.size() >= 180: _finish.call_deferred()

func _draw_begin() -> void:
	if not ended and not current_frame.is_empty(): current_frame["pre_draw_usec"] = Time.get_ticks_usec()

func _draw_end() -> void:
	if ended or current_frame.is_empty(): return
	current_frame["post_draw_usec"] = Time.get_ticks_usec()
	current_frame["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	current_frame["last_process_seconds"] = Performance.get_monitor(Performance.TIME_PROCESS)
	current_frame["engine_static_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	if map_seen and not capture_done and Time.get_ticks_usec()-began > 3000000:
		capture_done = true
		var started: int = Time.get_ticks_usec()
		var picture: Image = root.get_texture().get_image()
		var read: int = Time.get_ticks_usec()
		var scale: float = 512.0/mini(picture.get_width(), picture.get_height())
		picture.resize(roundi(picture.get_width()*scale), roundi(picture.get_height()*scale), Image.INTERPOLATE_LANCZOS)
		var result: Error = picture.save_webp(output + "/viewport.webp", false, .9)
		if result != OK: errors.append("Native viewport capture failed")
		events.append({"event": "capture", "engine_usec": started, "readback_end_usec": read, "end_usec": Time.get_ticks_usec(), "frame": Engine.get_process_frames()})

func _run() -> void:
	if not errors.is_empty(): _finish(); return
	_stamp("load_begin")
	var selected: String = "res://scenes/main/windows_candidate_bootstrap.tscn" if loading_screen else model_scene
	var packed := load(selected) as PackedScene
	_stamp("load_end")
	if packed == null:
		errors.append("Candidate scene failed to load")
		_finish()
		return
	_stamp("instantiate_begin")
	var instance: Node = packed.instantiate()
	if loading_screen:
		bootstrap = instance
		bootstrap.phase_changed.connect(_bootstrap_phase)
	else: game = instance as Node3D
	_stamp("instantiate_end")
	_stamp("add_child_begin")
	root.add_child(instance)
	current_scene = instance
	_stamp("add_child_end")
	if not loading_screen: game.get("travel").map_changed.connect(func(_map: Node3D) -> void: _stamp("map_changed"))

func _bootstrap_phase(value: String) -> void:
	_stamp("bootstrap_"+value)
	if value == "splash_presented":
		var before: int = Time.get_ticks_usec()
		var picture: Image = root.get_texture().get_image()
		var factor: float = 512.0/mini(picture.get_width(),picture.get_height())
		picture.resize(roundi(picture.get_width()*factor),roundi(picture.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		if picture.save_webp(output+"/loading_screen.webp",false,.9) != OK: errors.append("Loading screen capture failed")
		events.append({"event":"splash_capture","engine_usec":before,"end_usec":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})

func _finish() -> void:
	if ended: return
	ended = true
	_stamp("finish")
	if not map_seen or not capture_done: errors.append("Candidate content was not observed/captured")
	if frames.size() < 60: errors.append("Too few native frame samples")
	var ready: bool = is_instance_valid(game) and bool(game.get("ready_to_play"))
	if not ready: errors.append("Candidate initialization did not finish")
	var report: Dictionary = {"engine": Engine.get_version_info().string, "release": not OS.is_debug_build(), "feature": OS.has_feature("g083_startup"), "display": DisplayServer.get_name(), "pid": OS.get_process_id(), "entry": model_scene, "loading_screen": loading_screen, "ready_to_play": ready, "vsync_mode": DisplayServer.window_get_vsync_mode(), "fps_limit": Engine.max_fps, "script_entry_engine_usec": began, "events": events, "frames": frames, "errors": errors, "method": "Embedded QA SceneTree observes unchanged RC3 candidate entry; pack hashes must separately prove shared resource equivalence. Wall times around real load/instantiate/add_child and rendering signals; no copied gameplay methods. Rendering intervals are not GPU timestamps. All frames, including capture, retained."}
	FileAccess.open(output + "/startup.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("G083_STARTUP_RESULT frames=%d errors=%d" % [frames.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
