extends "res://scripts/core/greystone_integration.gd"
var qa_validation_samples: Array[Dictionary] = []

func validate_loaded_position(location: Dictionary, candidate_flags: Dictionary) -> bool:
	var qa_started: int = Time.get_ticks_usec()
	# Query a separate physics world, so validation cannot alter the active map.
	var selected: PackedScene
	for scene: PackedScene in travel.maps:
		if scene.resource_path.get_file().get_basename() == location.map: selected = scene
	if location.map in ["forest", "mine"] and int(location.get("layout_version", 1)) == 1:
		selected = load("res://scenes/world/%s.tscn" % location.map)
	if selected == null: return false
	var viewport: SubViewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var qa_world: int = Time.get_ticks_usec()
	var candidate: Node3D = selected.instantiate() as Node3D
	var qa_instantiated: int = Time.get_ticks_usec()
	viewport.add_child(candidate)
	var qa_added: int = Time.get_ticks_usec()
	# Reconstruct dynamic collision from the already validated candidate, not this session.
	for target: Node in candidate.find_children("*", "WorldInteractable", true, false):
		if (target as WorldInteractable).interaction_id == &"npc_lia":
			(target as WorldInteractable).set_present(not candidate_flags.get("e003_done", false))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var qa_waited: int = Time.get_ticks_usec()
	var position: Vector3 = Vector3(location.x, location.y, location.z)
	var shape: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.06) * shape.transform
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = viewport.world_3d.direct_space_state
	var empty: bool = space.intersect_shape(query, 1).is_empty()
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.15, position + Vector3.DOWN * 0.35, 1)
	var grounded: bool = not space.intersect_ray(ray).is_empty()
	viewport.queue_free()
	qa_validation_samples.append({"map":str(location.map),"world_and_select_ms":(qa_world-qa_started)/1000.0,"instantiate_ms":(qa_instantiated-qa_world)/1000.0,"ready_ms":(qa_added-qa_instantiated)/1000.0,"dynamic_and_physics_wait_ms":(qa_waited-qa_added)/1000.0,"query_and_free_ms":(Time.get_ticks_usec()-qa_waited)/1000.0,"accepted":empty and grounded})
	return empty and grounded
