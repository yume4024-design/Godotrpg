@tool
extends EditorScenePostImport
## Preserve the authored terrain palette while sharing resources across GLBs.
func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null: continue
		for surface: int in range(mesh.get_surface_count()):
			var original: Material = mesh.surface_get_material(surface)
			if original == null: continue
			var path: String = "res://assets/materials/greystone/terrain/%s.tres" % original.resource_name.to_lower().replace("greystone_", "terrain_")
			if ResourceLoader.exists(path):
				mesh.surface_set_material(surface, load(path))
			else:
				push_error("Missing shared terrain material: " + path)
	return scene
