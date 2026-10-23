extends WindowsCandidateBootstrap
## Reuses the loading boundary; only this candidate owns deferred native shutdown.
var _closing: bool = false

func _ready() -> void:
	super._ready()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_request_exit)
	game_ready.connect(func(_instance: Node3D) -> void: print("BLENDER_WINDOWS_READY"))

func _request_exit() -> void:
	if _closing: return
	_closing = true
	if is_instance_valid(exit_button): exit_button.disabled = true
	while _discarding_game: await get_tree().process_frame
	var tree: SceneTree = get_tree()
	tree.current_scene = null
	queue_free()
	tree.create_timer(.25).timeout.connect(tree.quit.bind(0), CONNECT_ONE_SHOT)
