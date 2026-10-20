extends Node3D
## Decorative prop; owns only its imported wheel pivot, never traversal state.

@export var model_scene: PackedScene
@export_range(0.0, 30.0, 0.1) var revolutions_per_minute: float = 7.5
@export var running: bool = true
var wheel: Node3D

func _ready() -> void:
	if model_scene == null:
		push_error("Waterwheel requires its model PackedScene")
		return
	var model := model_scene.instantiate() as Node3D
	add_child(model)
	wheel = model.find_child("Wheel", true, false) as Node3D
	if wheel == null:
		push_error("Waterwheel GLB is missing its Wheel pivot")

func _process(delta: float) -> void:
	if running and is_instance_valid(wheel):
		wheel.rotation.x = fposmod(wheel.rotation.x + TAU * revolutions_per_minute * delta / 60.0, TAU)
