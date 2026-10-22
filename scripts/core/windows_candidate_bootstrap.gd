class_name WindowsCandidateBootstrap
extends Node
## Presentation-only startup boundary. The existing game owns all RPG state.
## A string path prevents loading the game while parsing this loading scene.

signal phase_changed(phase: String)
signal game_created(instance: Node3D)
signal game_ready(instance: Node3D)
signal loading_failed(message: String)

@export_file("*.tscn") var game_scene_path: String = "res://scenes/main/greystone_preview.tscn"
@export var timeout_seconds: float = 25.0
@onready var status: Label = %Status
@onready var progress: ProgressBar = %Progress
@onready var loading_canvas: CanvasLayer = %LoadingCanvas
@onready var exit_button: Button = %ExitButton
var game: Node3D
var phase: String = "initializing"
var timings: Array[Dictionary] = []
var _started_usec: int
var _discarding_game: bool = false

func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	Engine.max_fps = 60
	exit_button.pressed.connect(_request_exit)
	_begin.call_deferred()

func _input(_event: InputEvent) -> void:
	if phase != "ready" and phase != "failed": get_viewport().set_input_as_handled()

func _phase(value: String, message: String, amount: float) -> void:
	phase = value
	status.text = message
	progress.value = amount
	timings.append({"phase": value, "engine_usec": Time.get_ticks_usec()})
	phase_changed.emit(value)

func _expired() -> bool:
	return Time.get_ticks_usec()-_started_usec > timeout_seconds*1000000.0

func _request_exit() -> void:
	exit_button.disabled = true
	while _discarding_game: await get_tree().process_frame
	# Match the existing preview's deferred native resource/audio shutdown.
	get_tree().create_timer(.2).timeout.connect(get_tree().quit, CONNECT_ONE_SHOT)

func _fail(message: String) -> void:
	_phase("failed", message, progress.value)
	if is_instance_valid(game):
		game.process_mode = Node.PROCESS_MODE_DISABLED
		_discarding_game = true
		_discard_failed_game.call_deferred()
	exit_button.show()
	exit_button.grab_focus()
	loading_failed.emit(message)

func _discard_failed_game() -> void:
	# A just-created World3D must complete its first rendering submission before
	# disposal. Cancelling it before that leaves GLES3 environment textures alive.
	await RenderingServer.frame_post_draw
	if is_instance_valid(game): game.queue_free()
	await get_tree().process_frame
	_discarding_game = false

func _begin() -> void:
	# Present the loading screen before any game load/instance/first-world work.
	await RenderingServer.frame_post_draw
	_phase("splash_presented", "正在準備旅程…", 8)
	await get_tree().process_frame
	if not ResourceLoader.exists(game_scene_path, "PackedScene"):
		_fail("找不到遊戲場景，請重新開啟。")
		return
	_phase("loading_resources", "正在準備地圖…", 12)
	await RenderingServer.frame_post_draw
	# The measured full-scene threaded path leaves RefCounted objects at exit in
	# this engine/project. The direct-load lifecycle control does not. Keep the
	# loading screen presented and use the verified synchronous scene boundary.
	var packed := load(game_scene_path) as PackedScene
	if packed == null:
		_fail("找不到遊戲場景，請重新開啟。")
		return
	_phase("creating_world", "正在準備隊伍…", 70)
	game = packed.instantiate() as Node3D
	if game == null:
		_fail("無法建立旅程，請重新開啟。")
		return
	game_created.emit(game)
	add_child(game)
	_phase("waiting_map", "正在準備旅程…", 80)
	while is_instance_valid(game) and (not bool(game.get("ready_to_play")) or bool(game.get("travel").get("transitioning"))):
		if _expired():
			_fail("旅程準備逾時，請重新開啟。")
			return
		await get_tree().process_frame
	if not is_instance_valid(game): return
	_phase("preparing_picture", "正在準備畫面…", 92)
	var stable_frames: int = 0
	while stable_frames < 2:
		var before: int = Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stable_frames = stable_frames+1 if Time.get_ticks_usec()-before <= 50000 else 0
		if _expired():
			_fail("畫面準備逾時，請重新開啟。")
			return
	_phase("fading", "準備完成", 100)
	var tween: Tween = create_tween()
	tween.tween_property(loading_canvas.get_child(0), "modulate:a", 0.0, .18)
	await tween.finished
	loading_canvas.queue_free()
	phase = "ready"
	timings.append({"phase": phase, "engine_usec": Time.get_ticks_usec()})
	phase_changed.emit(phase)
	set_process_input(false)
	game_ready.emit(game)
