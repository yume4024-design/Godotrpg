extends CartoonActor
var skeleton: Skeleton3D
var rest_rotations: Dictionary = {}

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in _model_root.find_children("*", "MeshInstance3D", true, false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
			material.vertex_color_use_as_albedo = true
			mesh.set_surface_override_material(surface, material)
	skeleton = _model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		for node: Node in _model_root.find_children("*", "Skeleton3D", true, false): skeleton = node

func _process(delta: float) -> void:
	if skeleton == null or _dead: return
	_phase += delta * lerpf(2.0, 8.0, _motion)
	for bone_name: String in ["ArmLeft", "ArmRight", "LegLeft", "LegRight", "Head", "Torso"]:
		var index: int = skeleton.find_bone(bone_name)
		if index < 0: continue
		var sign_value: float = -1.0 if bone_name in ["ArmLeft", "LegRight"] else 1.0
		var angle: float = sin(_phase) * _motion * .18 * sign_value
		if bone_name in ["Head", "Torso"]: angle = sin(_phase*.5)*.012
		if not rest_rotations.has(index): rest_rotations[index] = skeleton.get_bone_pose_rotation(index)
		skeleton.set_bone_pose_rotation(index, rest_rotations[index] * Quaternion(Vector3.RIGHT, angle))

func set_dead(value: bool) -> void:
	super.set_dead(value)
	if skeleton != null and value: skeleton.reset_bone_poses()
