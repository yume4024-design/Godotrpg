extends "res://tests/greystone_layout_test.gd"
## Facade checks complement the continuous-route test; resets isolate each entrance.

func _run() -> void:
	game = load("res://scenes/world/greystone_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	Engine.physics_ticks_per_second = 90
	Engine.time_scale = 3.0
	var palette: Dictionary = {}
	var shared: bool = true
	var buildings: Node = game.get_node("Village/Buildings")
	for building: Node3D in buildings.get_children():
		for mesh_node: Node in building.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mesh_node as MeshInstance3D).mesh
			for index: int in range(mesh.get_surface_count()):
				var mat: Material = mesh.surface_get_material(index)
				shared = shared and mat != null and mat.resource_path.begins_with("res://assets/materials/greystone/")
				if mat == null:
					continue
				if palette.has(mat.resource_path):
					shared = shared and palette[mat.resource_path] == mat
				palette[mat.resource_path] = mat
		var door: Marker3D = building.get_node("DoorApproach")
		_check(float(door.get_meta("door_width_m")) >= 1.5, "%s door panel >= 1.5m" % building.name)
		var approach: Vector3 = door.global_position
		player.reset_to(approach + Vector3(0, 0.6, 2.0))
		await create_timer(0.6).timeout
		await _walk(Vector2(approach.x, approach.z))
		_check(player.is_on_floor(), "%s entrance is supported" % building.name)
		await _walk(Vector2(approach.x, approach.z - 2.0), false, 70)
		_check(player.position.z > approach.z - 0.85 and player.position.z < approach.z - 0.3, "%s closed door blocks at facade" % building.name)
		await _walk(Vector2(approach.x, approach.z + 1.0))
		if DisplayServer.get_name() != "headless":
			game.camera.size = 20.0
			await _capture("detail-" + building.name.to_snake_case())
	_check(shared and palette.size() == 9, "All seven buildings share nine external material resources")
	print("GREYSTONE_BUILDINGS_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
