extends SceneTree
## Authoring-only: bake the exact legacy AABB conversion into reusable collision data.
const SOURCE: String = "res://assets/models/greystone/reference_v5/bounds.glb"
const OUTPUT: String = "res://assets/collisions/greystone/reference_v5/bounds.tscn"

func _initialize() -> void:
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		push_error("Missing reference collision source")
		quit(1)
		return
	var instance := packed.instantiate() as Node3D
	var shapes: Dictionary = {}
	var count: int = 0
	for node: Node in instance.find_children("*", "CollisionShape3D", true, false):
		var collider := node as CollisionShape3D
		if not collider.shape is ConcavePolygonShape3D:
			continue
		var faces: PackedVector3Array = (collider.shape as ConcavePolygonShape3D).get_faces()
		if faces.is_empty():
			push_error("Empty source collision " + str(instance.get_path_to(collider)))
			instance.free()
			quit(1)
			return
		var bounds := AABB(faces[0], Vector3.ZERO)
		for point: Vector3 in faces:
			bounds = bounds.expand(point)
		if not shapes.has(bounds.size):
			var box := BoxShape3D.new()
			box.size = bounds.size
			shapes[bounds.size] = box
		collider.transform = collider.transform * Transform3D(Basis.IDENTITY, bounds.get_center())
		collider.shape = shapes[bounds.size]
		count += 1
	for node: Node in instance.find_children("*", "", true, false):
		node.owner = instance
	instance.set_meta("source_path", SOURCE)
	instance.set_meta("source_sha256", FileAccess.get_sha256(SOURCE))
	instance.set_meta("recipe", "bake_reference_bounds_v1_exact_aabb")
	instance.set_meta("source_collision_count", count)
	var result := PackedScene.new()
	var error: Error = result.pack(instance)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
		error = ResourceSaver.save(result, OUTPUT)
	instance.free()
	if error != OK:
		push_error("Collision bake failed: " + str(error))
		quit(1)
		return
	print("REFERENCE_BOUNDS_BAKE count=%d unique_shapes=%d output=%s" % [count, shapes.size(), OUTPUT])
	quit(0)
