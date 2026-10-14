extends "res://tests/greystone_layout_test.gd"

func _run() -> void:
	game = load("res://scenes/world/greystone_asset_preview.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var palette: Dictionary = {}
	var assets: Node = game.get_node("Assets")
	_check(assets.get_child_count() == 17, "17 reusable props load")
	for prop: Node in assets.get_children():
		var triangles: int = 0
		var valid: bool = true
		for node: Node in prop.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			triangles += mesh.get_faces().size() / 3
			for index: int in range(mesh.get_surface_count()):
				var material: Material = mesh.surface_get_material(index)
				valid = valid and material != null and material.resource_path.begins_with("res://assets/materials/greystone/props/")
				if material == null: continue
				valid = valid and (material as StandardMaterial3D).albedo_texture == null
				if palette.has(material.resource_path):
					valid = valid and palette[material.resource_path] == material
				palette[material.resource_path] = material
		_check(triangles > 0 and triangles < 1500 and valid, "%s geometry and shared untextured palette (%d triangles)" % [prop.name,triangles])
		for collision: Node in prop.find_children("*", "CollisionShape3D",true,false):
			_check((collision as CollisionShape3D).scale == Vector3.ONE, "%s unscaled collision" % prop.name)
	_check(palette.size() == 9,"Nine shared materials")
	await create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/greystone-g04")
		_check(root.get_texture().get_image().save_webp("res://artifacts/greystone-g04/asset-preview.webp") == OK,"Asset preview capture")
		var camera: Camera3D = game.get_node("Camera3D")
		for name: String in ["flower_a", "bush_a", "crystal_blue", "wooden_bridge", "wooden_dock"]:
			var prop: Node3D = assets.get_node(name)
			camera.position = prop.position + Vector3(8,11.31,8)
			camera.look_at(prop.position)
			camera.size = 12.0
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_webp("res://artifacts/greystone-g04/%s.webp" % name) == OK,"Detail capture " + name)
	print("GREYSTONE_PROPS_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
