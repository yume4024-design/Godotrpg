class_name BlenderVillageGeometry
extends Node3D
## Shared imported-ground adapter used by exploration and isolated physics validation.
func _ready() -> void:
	# Blender Bounds contains only authored rectangular proxies. glTF -colonly
	# imports them as hollow triangle soups; use solid boxes so a save position
	# entirely inside a building is rejected by intersect_shape as well.
	for node: Node in get_node("Bounds").find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = node as CollisionShape3D
		if collision.shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array = (collision.shape as ConcavePolygonShape3D).get_faces()
			if faces.is_empty(): continue
			var bounds := AABB(faces[0], Vector3.ZERO)
			for point: Vector3 in faces: bounds = bounds.expand(point)
			var box := BoxShape3D.new()
			box.size = bounds.size
			collision.transform = collision.transform * Transform3D(Basis.IDENTITY, bounds.get_center())
			collision.shape = box
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var relative: String = str(get_path_to(mesh))
		var ground: bool = relative.begins_with("Terrain/") and "Grass" in mesh.name
		var road: bool = relative.begins_with("Paths/") and (not "Steps" in mesh.name or "RampCollisionGuide" in mesh.name)
		var facility: bool = relative.begins_with("Props/") and ("Bridge" in mesh.name or "Dock" in mesh.name or "Well" in mesh.name)
		if ground or (road and "RampCollisionGuide" in mesh.name):
			_solid_ground(mesh)
		elif road or facility:
			mesh.create_trimesh_collision()

func _solid_ground(mesh: MeshInstance3D) -> void:
	# Extrude the same clipped top triangles to the authored basement. This closes
	# retaining walls and rejects positions inside overlapping higher terraces.
	var body := StaticBody3D.new()
	body.name = "SolidTerrain"
	mesh.add_child(body)
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	for index: int in range(0, faces.size(), 3):
		if (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).length_squared() < 0.000000000001: continue
		var points: PackedVector3Array = PackedVector3Array()
		for corner: int in 3: points.append(faces[index + corner])
		for corner: int in 3:
			var point: Vector3 = to_local(mesh.to_global(faces[index + corner]))
			point.y = -5.0
			points.append(mesh.to_local(to_global(point)))
		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		var collision := CollisionShape3D.new()
		collision.shape = hull
		body.add_child(collision)
