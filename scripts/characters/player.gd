class_name ExplorationPlayer
extends CharacterBody3D

@export var movement_camera: Camera3D
@onready var input_component: PlayerInput = %PlayerInput
@onready var movement: PlayerMovement = %PlayerMovement
@onready var visual: Node3D = %Visual
@onready var appearance: CartoonActor = %Appearance


func _physics_process(delta: float) -> void:
	var camera_basis: Basis = Basis.IDENTITY
	if is_instance_valid(movement_camera):
		camera_basis = movement_camera.global_basis
	var direction: Vector3 = movement.step(self, input_component.read_direction(), camera_basis, delta)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if appearance.has_method("set_travel_speed"):
		appearance.call("set_travel_speed",horizontal_speed)
	appearance.set_motion(horizontal_speed / movement.speed)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 14.0 * delta)


func reset_to(spawn: Vector3) -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	reset_physics_interpolation()
