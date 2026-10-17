extends AnimatableBody3D
var moving: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	process_physics_priority = -100

func _physics_process(delta: float) -> void:
	if not moving: return
	_elapsed += delta
	position = Vector3(.2*sin(_elapsed*PI*.5),.25*sin(_elapsed*PI),0)
