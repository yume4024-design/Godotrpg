extends SceneTree
## Run before enabling terrain_import on the GLBs. Reject same-name variants.
func _initialize() -> void:
	var palette: Dictionary = {}
	var signatures: Dictionary = {}
	var scene: Node = load("res://scenes/world/greystone_runtime.tscn").instantiate()
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null: continue
		for surface: int in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(surface)
			if mat == null or not mat.resource_name.begins_with("Greystone_"): continue
			var signature: Dictionary = {}
			for property: Dictionary in mat.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in ["resource_name", "resource_path"]:
					signature[property.name] = mat.get(property.name)
			if signatures.has(mat.resource_name) and signatures[mat.resource_name] != signature:
				push_error("Palette name has distinct properties: " + mat.resource_name)
				scene.free()
				quit(1)
				return
			signatures[mat.resource_name] = signature
			palette[mat.resource_name] = mat
	DirAccess.make_dir_recursive_absolute("res://assets/materials/greystone/terrain")
	for key: String in palette:
		var error: Error = ResourceSaver.save(palette[key], "res://assets/materials/greystone/terrain/%s.tres" % key.to_lower().replace("greystone_", "terrain_"))
		if error != OK:
			push_error("Palette save failed: " + key)
			scene.free()
			quit(1)
			return
	print("TERRAIN_PALETTE_RESULT materials=%d failures=0" % palette.size())
	scene.free()
	quit()
