@tool
extends EditorScenePostImport
## All Greystone buildings resolve to the same external palette resources.

func _post_import(scene: Node) -> Object:
	_apply_palette(scene)
	return scene

func _apply_palette(node: Node) -> void:
	if node is MeshInstance3D:
		var visual: MeshInstance3D = node as MeshInstance3D
		if visual.mesh is ArrayMesh:
			var mesh: ArrayMesh = visual.mesh as ArrayMesh
			for index: int in range(mesh.get_surface_count()):
				var original: Material = mesh.surface_get_material(index)
				if original == null:
					continue
				var key: String = original.resource_name.trim_prefix("CrystalG03_").to_snake_case()
				var path: String = "res://assets/materials/greystone/%s.tres" % key
				if ResourceLoader.exists(path):
					mesh.surface_set_material(index, load(path) as Material)
				else:
					push_error("Missing Greystone palette: " + path)
	for child: Node in node.get_children():
		_apply_palette(child)
