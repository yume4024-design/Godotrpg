@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	_apply(scene)
	return scene

func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for index: int in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(index)
			var key: String = material.resource_name.trim_prefix("G04_")
			var path: String = "res://assets/materials/greystone/props/%s.tres" % key
			if ResourceLoader.exists(path):
				mesh.surface_set_material(index, load(path))
			else:
				push_error("Missing G04 material: " + path)
	for child: Node in node.get_children():
		_apply(child)
