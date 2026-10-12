class_name PlayerMovement
extends Node

@export_range(1.0, 10.0) var speed: float = 4.5


func step(body: CharacterBody3D, input_direction: Vector2, camera_basis: Basis, delta: float) -> Vector3:
	var right: Vector3 = camera_basis.x
	var back: Vector3 = camera_basis.z
	right.y = 0.0
	back.y = 0.0
	var direction: Vector3 = right.normalized() * input_direction.x + back.normalized() * input_direction.y
	direction = direction.limit_length(1.0)
	body.velocity.x = direction.x * speed
	body.velocity.z = direction.z * speed
	if body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity += body.get_gravity() * delta
	body.move_and_slide()
	return direction
