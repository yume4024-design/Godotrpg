extends SceneTree
## Independent comparison with the previous runtime conversion; not just node counts.
const SOURCE: String = "res://assets/models/greystone/reference_v5/bounds.glb"
const BAKED: String = "res://assets/collisions/greystone/reference_v5/bounds.tscn"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 20: print("FAIL ", label)

func _world() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	return viewport

func _legacy_convert(original: Node3D) -> int:
	var count: int = 0
	for node: Node in original.find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		if collider.shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = (collider.shape as ConcavePolygonShape3D).get_faces()
			var bounds := AABB(faces[0], Vector3.ZERO)
			for point: Vector3 in faces:
				bounds = bounds.expand(point)
			var box := BoxShape3D.new()
			box.size = bounds.size
			collider.transform = collider.transform * Transform3D(Basis.IDENTITY, bounds.get_center())
			collider.shape = box
			count += 1
	return count

func _run() -> void:
	var original: Node3D = load(SOURCE).instantiate()
	var baked: Node3D = load(BAKED).instantiate()
	var count: int = _legacy_convert(original)
	_check(count > 0 and baked.get_meta("source_collision_count") == count, "Complete imported collision inventory baked")
	_check(baked.get_meta("source_path") == SOURCE and baked.get_meta("source_sha256") == FileAccess.get_sha256(SOURCE), "Baked data matches current source bytes")
	var old_nodes: Array[Node] = original.find_children("*", "", true, false)
	_check(old_nodes.size() == baked.find_children("*", "", true, false).size(), "All source nodes preserved")
	var shapes: Dictionary = {}
	for node: Node in old_nodes:
		var peer: Node = baked.get_node_or_null(original.get_path_to(node))
		_check(peer != null and peer.get_class() == node.get_class(), "Node identity " + str(node.name))
		if peer == null: continue
		if node is Node3D:
			_check((node as Node3D).transform.is_equal_approx((peer as Node3D).transform), "Local placement " + str(node.name))
		if node is StaticBody3D:
			var a := node as StaticBody3D
			var b := peer as StaticBody3D
			_check(a.collision_layer == b.collision_layer and a.collision_mask == b.collision_mask, "Physics layers preserved")
		if node is CollisionShape3D:
			var a := node as CollisionShape3D
			var b := peer as CollisionShape3D
			_check(b.shape is BoxShape3D and (a.shape as BoxShape3D).size.is_equal_approx((b.shape as BoxShape3D).size), "Box dimensions preserve legacy volume")
			_check(a.disabled == b.disabled and a.shape.margin == b.shape.margin, "Collision flags and margin preserved")
			shapes[b.shape] = true
	_check(shapes.size() < count, "Equal box sizes share immutable shape resources")
	var original_world := _world()
	var baked_world := _world()
	original_world.add_child(original)
	baked_world.add_child(baked)
	await physics_frame
	await physics_frame
	var a: PhysicsDirectSpaceState3D = original_world.world_3d.direct_space_state
	var b: PhysicsDirectSpaceState3D = baked_world.world_3d.direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .32
	capsule.height = 1.95
	for x: int in range(-56, 57, 4):
		for z: int in range(-56, 57, 4):
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 32, z), Vector3(x, -12, z), 1)
			var hit_a: Dictionary = a.intersect_ray(ray)
			var hit_b: Dictionary = b.intersect_ray(ray)
			_check(hit_a.is_empty() == hit_b.is_empty(), "Physics ray availability")
			if not hit_a.is_empty() and not hit_b.is_empty():
				_check((hit_a.position as Vector3).distance_to(hit_b.position) < .001, "Physics hit position matches")
			for y: float in [1.0, 4.0, 11.0]:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform.origin = Vector3(x, y, z)
				query.collision_mask = 1
				_check(a.intersect_shape(query, 1).is_empty() == b.intersect_shape(query, 1).is_empty(), "Player volume blocking matches")
	original_world.free()
	baked_world.free()
	await physics_frame
	DirAccess.make_dir_recursive_absolute("user://reference_bounds")
	FileAccess.open("user://reference_bounds/report.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "source_colliders": count, "unique_shapes": shapes.size(), "source_sha256": FileAccess.get_sha256(SOURCE), "engine": Engine.get_version_info().string}, "  "))
	print("REFERENCE_BOUNDS_RESULT checks=%d failures=%d colliders=%d unique_shapes=%d" % [checks, failures, count, shapes.size()])
	quit(0 if failures == 0 else 1)
