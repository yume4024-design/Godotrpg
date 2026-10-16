extends "res://scripts/core/greystone_integration.gd"
## Independent preview shutdown gives audio playback a few frames to release.
var _quitting: bool = false

func _ready() -> void:
	super._ready()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_request_exit)
	if "--preview-smoke" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_request_exit,CONNECT_ONE_SHOT)

func _request_exit() -> void:
	if _quitting: return
	_quitting = true
	var tree: SceneTree = get_tree()
	tree.current_scene = null
	queue_free()
	tree.create_timer(.15).timeout.connect(tree.quit.bind(0),CONNECT_ONE_SHOT)
