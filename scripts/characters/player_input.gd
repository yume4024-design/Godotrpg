class_name PlayerInput
extends Node
## Input sampling is isolated so later dialogue can disable exploration input.

var enabled: bool = true
var _window_focused: bool = true


func read_direction() -> Vector2:
	if not enabled or not _window_focused:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
