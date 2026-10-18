class_name PlayerMovement
extends Node

@export_range(1.0, 10.0) var speed: float = 4.5
## Disabled in the legacy entry. A full capsule sweep checks ceiling and landing.
@export_range(0.0, 0.25) var max_step_height: float = 0.0


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
	if max_step_height > 0.0 and body.is_on_floor() and direction.length_squared() > .001:
		_try_step_up(body, direction * speed * delta)
	body.move_and_slide()
	return direction


func _try_step_up(body: CharacterBody3D, motion: Vector3) -> void:
	var start: Transform3D = body.global_transform
	var wall: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(start, motion, wall): return
	# Ordinary slopes are handled by move_and_slide, not by stair lifting.
	if wall.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle): return
	var lift: Vector3 = Vector3.UP * max_step_height
	if body.test_move(start, lift): return
	var raised: Transform3D = start
	raised.origin += lift
	if body.test_move(raised, motion): return
	var ahead: Transform3D = raised
	ahead.origin += motion
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(ahead, -lift, landing): return
	if landing.get_normal().dot(Vector3.UP) < cos(body.floor_max_angle): return
	var rise: float = max_step_height + landing.get_travel().y
	if rise < .01 or rise > max_step_height: return
	# Lift only: horizontal travel still goes through the normal collision solver.
	body.global_position.y += rise
	body.velocity.y = 0.0
