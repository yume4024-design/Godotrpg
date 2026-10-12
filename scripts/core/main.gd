extends Node3D

@export var spawn_position: Vector3 = Vector3(0.0, 0.1, 4.0)
@onready var player: ExplorationPlayer = %Player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_position") and not event.is_echo():
		player.reset_to(spawn_position)
		get_viewport().set_input_as_handled()
