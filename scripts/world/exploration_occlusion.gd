class_name ExplorationOcclusion
extends Node
## Presentation only. Explicitly registered timbers retain shadows and collision.
var target: Node3D
var camera: Camera3D
var enabled: bool = false
var _meshes: Array[MeshInstance3D] = []
var _original: Array[int] = []
var _blocked: Array[bool] = []

func set_map(map: ExplorationMap) -> void:
	_restore()
	_meshes.clear()
	_original.clear()
	_blocked.clear()
	if not is_instance_valid(map) or map.map_id != &"mine": return
	for node: Node in map.get_tree().get_nodes_in_group(&"exploration_occluder"):
		if node is MeshInstance3D and map.is_ancestor_of(node):
			_meshes.append(node)
			_original.append(node.cast_shadow)
			_blocked.append(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera): return
	for index: int in range(_meshes.size()):
		var mesh: MeshInstance3D = _meshes[index]
		if not is_instance_valid(mesh): continue
		var blocked: bool = false
		if enabled and target.is_visible_in_tree() and camera.is_current():
			# Mesh-local segment handles rotated/scaled timbers without physics proxies.
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var bounds: AABB = mesh.get_aabb().grow(.12 if _blocked[index] else .06)
			for height: float in [.4, 1.0, 1.6]:
				var point: Vector3 = target.global_position + Vector3.UP*height
				# Orthographic rays are parallel, not rays from the camera center.
				var screen: Vector2 = camera.unproject_position(point)
				var start: Vector3 = inverse * camera.project_ray_origin(screen)
				var end: Vector3 = inverse * point
				if bounds.intersects_segment(start, end):
					blocked = true
					break
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if blocked else _original[index]
		_blocked[index] = blocked

func _restore() -> void:
	for index: int in range(_meshes.size()):
		if is_instance_valid(_meshes[index]): _meshes[index].cast_shadow = _original[index]

func _exit_tree() -> void:
	_restore()
