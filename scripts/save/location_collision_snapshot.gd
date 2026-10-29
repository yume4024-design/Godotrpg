class_name LocationCollisionSnapshot
extends RefCounted
## Immutable, per-map validation geometry captured before story-dependent NPC hiding.
## No meshes, scripts, materials, animations or live-world shape references are retained.
var bodies: Array[Dictionary] = []

static func capture(map: Node3D) -> LocationCollisionSnapshot:
	# Unusual physics bodies need their original scene behavior, not an approximation.
	for node: Node in map.find_children("*", "PhysicsBody3D", true, false):
		if not node is StaticBody3D:
			return null
	if not map.global_transform.is_equal_approx(map.transform):
		return null
	var result := LocationCollisionSnapshot.new()
	var copied_shapes: Dictionary = {}
	for node: Node in map.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		var target: Node = body.get_parent()
		var is_lia: bool = false
		while target != null and target != map:
			if target is WorldInteractable and (target as WorldInteractable).interaction_id == &"npc_lia":
				is_lia = true
			target = target.get_parent()
		var owners: Array[Dictionary] = []
		for owner_id: int in body.get_shape_owners():
			var shapes: Array[Shape3D] = []
			for index: int in body.shape_owner_get_shape_count(owner_id):
				var shape: Shape3D = body.shape_owner_get_shape(owner_id, index)
				if not copied_shapes.has(shape):
					copied_shapes[shape] = shape.duplicate(true)
				shapes.append(copied_shapes[shape])
			owners.append({"transform":body.shape_owner_get_transform(owner_id),"disabled":body.is_shape_owner_disabled(owner_id),"shapes":shapes})
		result.bodies.append({"transform":body.global_transform,"layer":body.collision_layer,"mask":body.collision_mask,"lia":is_lia,"owners":owners})
	return result

func instantiate(candidate_flags: Dictionary) -> Node3D:
	var result := Node3D.new()
	for row: Dictionary in bodies:
		var body := StaticBody3D.new()
		body.transform = row.transform
		body.collision_layer = (0 if candidate_flags.get("e003_done", false) else 1) if row.lia else int(row.layer)
		body.collision_mask = int(row.mask)
		result.add_child(body)
		for data: Dictionary in row.owners:
			var owner_id: int = body.create_shape_owner(body)
			body.shape_owner_set_transform(owner_id, data.transform)
			for shape: Shape3D in data.shapes:
				body.shape_owner_add_shape(owner_id, shape)
			body.shape_owner_set_disabled(owner_id, data.disabled)
	return result
