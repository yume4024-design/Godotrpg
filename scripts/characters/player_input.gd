class_name PlayerInput
extends Node
## Input sampling is isolated so later dialogue can disable exploration input.

var enabled: bool = true
var _window_focused: bool = true


func _input(event: InputEvent) -> void:
	# LB is also menu focus-previous. While exploration owns input, sampling the
	# same InputMap action must not cycle background buttons. Menus disable this
	# component and keep their existing shoulder navigation.
	if enabled and _window_focused and event is InputEventJoypadButton and event.is_action(&"move_run"):
		get_viewport().set_input_as_handled()


func read_direction() -> Vector2:
	if not enabled or not _window_focused:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func read_run() -> bool:
	return enabled and _window_focused and Input.is_action_pressed(&"move_run")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
