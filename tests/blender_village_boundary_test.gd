extends SceneTree
## Independent physics sweep of actual imported terrain edges, not guard metadata.
var failures: Array[String] = []
var checked: int = 0
var obstructed_starts: int = 0
var diagnostics: Array[Dictionary] = []
var covered_lower_edges: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _point_key(point: Vector3) -> String:
	return "%.5f,%.5f,%.5f" % [point.x, point.y, point.z]

func _floor(space: PhysicsDirectSpaceState3D, point: Vector3, depth: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point + Vector3.DOWN * depth, 1))

func _run() -> void:
	var world: Node3D = load("res://scenes/world/greystone_blender_master.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.95
	capsule.radius = 0.28
	var boundary_edges: int = 0
	for node: Node in world.get_node("Terrain").find_children("*Grass*", "MeshInstance3D", true, false):
		var surface: MeshInstance3D = node as MeshInstance3D
		var faces: PackedVector3Array = surface.mesh.get_faces()
		var edges: Dictionary = {}
		for index: int in range(0, faces.size(), 3):
			for side: int in 3:
				var a: Vector3 = surface.global_transform * faces[index + side]
				var b: Vector3 = surface.global_transform * faces[index + (side + 1) % 3]
				var ka: String = _point_key(a)
				var kb: String = _point_key(b)
				var key: String = ka + "|" + kb if ka < kb else kb + "|" + ka
				if not edges.has(key): edges[key] = {"a":a, "b":b, "count":0}
				edges[key].count += 1
		for edge: Dictionary in edges.values():
			if edge.count != 1: continue
			var delta: Vector3 = edge.b - edge.a
			delta.y = 0
			if delta.length() < 0.1: continue
			boundary_edges += 1
			var normal := Vector3(-delta.z, 0, delta.x).normalized()
			var samples: int = maxi(1, ceili(delta.length() / 1.2))
			for sample: int in samples:
				var middle: Vector3 = edge.a.lerp(edge.b, (sample + 0.5) / samples)
				for sign: float in [-1.0, 1.0]:
					var start: Vector3 = middle + normal * sign * 0.9
					var end: Vector3 = middle - normal * sign * 1.3
					if _floor(space, start, 0.35).is_empty(): continue
					# Lower slab outlines underneath a ramp/upper floor are not
					# reachable walking edges; identify them from actual top physics.
					var top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3.UP * 30, start + Vector3.DOWN * 24, 1))
					if not top.is_empty() and top.position.y > start.y + 0.35:
						covered_lower_edges += 1
						continue
					# Drops to another authored floor are not an off-map abyss.
					if not _floor(space, end, 24).is_empty(): continue
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = capsule
					query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 1.035)
					query.collision_mask = 1
					if not space.intersect_shape(query, 1).is_empty():
						obstructed_starts += 1
						continue
					query.motion = end - start
					var fractions: PackedFloat32Array = space.cast_motion(query)
					checked += 1
					if fractions.size() != 2 or fractions[0] > 0.99:
						failures.append(str(surface.name) + " " + str(start) + " -> " + str(end))
						var tops: Dictionary = {}
						for key: String in ["start", "end"]:
							var p: Vector3 = start if key == "start" else end
							var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30, p + Vector3.DOWN * 24, 1))
							if not hit.is_empty(): tops[key] = {"position":str(hit.position), "collider":str(hit.collider.get_path())}
						diagnostics.append(tops)
	var report: Dictionary = {"tested_terrain_edges":boundary_edges, "abyss_sweeps":checked, "already_obstructed_starts":obstructed_starts, "covered_lower_edges":covered_lower_edges, "failures":failures, "failure_top_down_diagnostics":diagnostics, "method":"Actual imported Grass mesh boundary edges, <=1.2m sampling; highest physical floor rejects covered outlines; 1.95m capsule sweep toward no floor within 24m"}
	var file := FileAccess.open("res://artifacts/greystone_blender_20261023/boundary_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("BLENDER_BOUNDARY_RESULT ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() and checked > 0 else 1)
