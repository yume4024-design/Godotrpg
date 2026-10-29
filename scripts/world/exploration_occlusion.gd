class_name ExplorationOcclusion
extends Node
## Presentation only. Timbers retain their existing shadow-only behavior.
## Opt-in forest canopies fade per instance; trunks and all collision stay intact.
var target: Node3D
var camera: Camera3D
var enabled: bool = false
var target_height: float = 1.6
var _meshes: Array[MeshInstance3D] = []
var _original: Array[int] = []
var _blocked: Array[bool] = []
var _map: ExplorationMap
var _foliage: Array[Dictionary] = []
const CANOPY_OPACITY: float = .12
const CANOPY_FADE_SPEED: float = 4.0

func set_map(map: ExplorationMap) -> void:
	_restore()
	_map = map
	_foliage.clear()
	_meshes.clear()
	_original.clear()
	_blocked.clear()
	if not is_instance_valid(map): return
	if map.map_id == &"forest":
		# Forest dressing is already queued by its _ready(). Register after its
		# local material palette exists, and reject a replaced/freed map.
		_collect_foliage.call_deferred(map)
		return
	if map.map_id != &"mine": return
	for node: Node in map.get_tree().get_nodes_in_group(&"exploration_occluder"):
		if node is MeshInstance3D and map.is_ancestor_of(node):
			_meshes.append(node)
			_original.append(node.cast_shadow)
			_blocked.append(false)

func _collect_foliage(map: ExplorationMap) -> void:
	if not is_instance_valid(map) or map != _map or not map.is_inside_tree() or not _foliage.is_empty(): return
	for node: Node in map.get_tree().get_nodes_in_group(&"exploration_foliage_occluder"):
		if not node is MeshInstance3D or not map.is_ancestor_of(node): continue
		var mesh := node as MeshInstance3D
		var surfaces: Array[Dictionary] = []
		for index: int in mesh.get_meta(&"occlusion_canopy_surfaces", PackedInt32Array()):
			var original := mesh.get_active_material(index) as StandardMaterial3D
			if original == null: continue
			surfaces.append({"index":index,"original":mesh.get_surface_override_material(index),"source":original,"fade":null})
		if not surfaces.is_empty():
			_foliage.append({"mesh":mesh,"surfaces":surfaces,"opacity":1.0,"blocked":false})

func _process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera):
		_restore()
		return
	var active: bool = enabled and target.is_visible_in_tree() and camera.is_current()
	for index: int in range(_meshes.size()):
		var mesh: MeshInstance3D = _meshes[index]
		if not is_instance_valid(mesh): continue
		var blocked: bool = active and _blocks(mesh, _blocked[index])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if blocked else _original[index]
		_blocked[index] = blocked
	for row: Dictionary in _foliage:
		var mesh: MeshInstance3D = row.mesh
		if not is_instance_valid(mesh): continue
		row.blocked = active and mesh.is_visible_in_tree() and _blocks(mesh, row.blocked)
		var desired: float = CANOPY_OPACITY if row.blocked else 1.0
		# Exploration hidden during battle restores immediately; walking fades smoothly.
		row.opacity = move_toward(row.opacity, desired, delta * CANOPY_FADE_SPEED) if active else 1.0
		for surface: Dictionary in row.surfaces:
			if row.opacity >= 1.0:
				if mesh.get_surface_override_material(surface.index) != surface.original:
					mesh.set_surface_override_material(surface.index, surface.original)
				continue
			if surface.fade == null:
				# Duplicate only when actually obstructing. Never edit shared GLB/palette materials.
				surface.fade = surface.source.duplicate() as StandardMaterial3D
				surface.fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var fade: StandardMaterial3D = surface.fade
			var color: Color = surface.source.albedo_color
			color.a *= row.opacity
			fade.albedo_color = color
			if mesh.get_surface_override_material(surface.index) != fade:
				mesh.set_surface_override_material(surface.index, fade)

func _blocks(mesh: MeshInstance3D, previously_blocked: bool) -> bool:
	# Mesh-local segments handle rotated/scaled models without physics proxies.
	var inverse: Transform3D = mesh.global_transform.affine_inverse()
	var bounds: AABB = mesh.get_aabb().grow(.12 if previously_blocked else .06)
	for height: float in [target_height * .25, target_height * .625, target_height]:
		var point: Vector3 = target.global_position + Vector3.UP * height
		# Orthographic rays are parallel, not rays from the camera center.
		var screen: Vector2 = camera.unproject_position(point)
		var start: Vector3 = inverse * camera.project_ray_origin(screen)
		if bounds.intersects_segment(start, inverse * point): return true
	return false

func _restore() -> void:
	for row: Dictionary in _foliage:
		if is_instance_valid(row.mesh):
			for surface: Dictionary in row.surfaces:
				row.mesh.set_surface_override_material(surface.index, surface.original)
		row.opacity = 1.0
		row.blocked = false
	for index: int in range(_meshes.size()):
		if is_instance_valid(_meshes[index]): _meshes[index].cast_shadow = _original[index]

func _exit_tree() -> void:
	_restore()
