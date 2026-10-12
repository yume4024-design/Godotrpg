class_name FixedExplorationCamera
extends Node3D
## Rotation is authored once in the scene; only position follows the target.

@export var target: Node3D
@export var focus_height: float = 0.7


func _physics_process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * focus_height
