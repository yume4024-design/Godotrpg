extends "res://scripts/world/expanded_wilderness.gd"
## Mine-only presentation adapter. Retain the original collision bodies, events,
## save locations and shared wilderness builder; replace only verified renderers.
const SUPPORT_VISUAL: PackedScene = preload("res://scenes/world/greystone/props/mine_support_frame_visual.tscn")

func _ready() -> void:
	super._ready()
	var originals: Array[Dictionary] = _original_renderers()
	if originals.size() != 24:
		push_error("Mine support geometry no longer matches the placement contract; original visuals retained.")
		return
	# Construct and validate off-tree before removing anything from the old map.
	var supports := Node3D.new()
	supports.name = "MineSupports"
	for x: int in [-12,-4,4,12]:
		for side: int in [-1,1]:
			var visual := SUPPORT_VISUAL.instantiate() as Node3D
			visual.name = "Support%d" % supports.get_child_count()
			visual.position = Vector3(x,0,side*16)
			supports.add_child(visual)
			var beam := visual.get_node_or_null(String(visual.get_meta("beam_node", ""))) as MeshInstance3D
			if beam == null or not visual.find_children("*", "CollisionShape3D", true, false).is_empty():
				supports.free()
				push_error("Mine support visual contract failed; original visuals retained.")
				return
			beam.add_to_group(&"exploration_occluder")
	for original: Dictionary in originals:
		var mesh: MeshInstance3D = original.visual
		if mesh.is_in_group(&"exploration_occluder"):
			mesh.remove_from_group(&"exploration_occluder")
		mesh.hide()
		# A post retains its original StaticBody and CollisionShape; the plain old
		# beam parent has no other behavior or children and can leave with its mesh.
		if original.solid: mesh.queue_free()
		else: (original.root as Node3D).queue_free()
	add_child(supports)

func _original_renderers() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for x: int in [-12,-4,4,12]:
		for side: int in [-1,1]:
			for offset: float in [-2.2,2.2]:
				var post: Dictionary = _renderer_at(Vector3(x+offset,1.2,side*16),Vector3(.25,2.4,.25),true)
				if post.is_empty(): return []
				found.append(post)
			var beam: Dictionary = _renderer_at(Vector3(x,2.5,side*16),Vector3(4.7,.25,.3),false)
			if beam.is_empty(): return []
			found.append(beam)
	return found

func _renderer_at(at: Vector3, dimensions: Vector3, solid: bool) -> Dictionary:
	var matches: Array[Dictionary] = []
	for child: Node in get_children():
		var node := child as Node3D
		if node == null or not node.position.is_equal_approx(at): continue
		if (node is StaticBody3D) != solid or node.get_child_count() != (2 if solid else 1): continue
		var visual: MeshInstance3D
		var collider: CollisionShape3D
		for component: Node in node.get_children():
			if component is MeshInstance3D: visual = component as MeshInstance3D
			elif component is CollisionShape3D: collider = component as CollisionShape3D
		if visual == null or not visual.mesh is BoxMesh or visual.transform != Transform3D.IDENTITY: continue
		if not (visual.mesh as BoxMesh).size.is_equal_approx(dimensions): continue
		if solid and (collider == null or not collider.shape is BoxShape3D or collider.transform != Transform3D.IDENTITY or not (collider.shape as BoxShape3D).size.is_equal_approx(dimensions)): continue
		matches.append({"root":node, "visual":visual, "solid":solid})
	return matches[0] if matches.size() == 1 else {}
