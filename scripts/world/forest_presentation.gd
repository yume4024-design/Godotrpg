extends Node3D
## Presentation only. No interaction, physics, story or saved-state ownership.

var _map: Node3D

func _ready() -> void:
	call_deferred("_dress")

func _surface(base: Color, grain: Color, grass: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/greystone/ground.gdshader")
	material.set_shader_parameter("base_color",base)
	material.set_shader_parameter("grain_color",grain)
	material.set_shader_parameter("grass_amount",grass)
	return material

func _dress() -> void:
	_map = get_parent() as Node3D
	var grass := _surface(Color(.24,.39,.22),Color(.45,.50,.27),.6)
	var palette: Dictionary = {}
	var rectangles := PackedVector4Array()
	var original_roads: Array[MeshInstance3D] = []
	# The old central-map decorative stone ring no longer bounds this expanded map.
	# Hide its artwork, retaining every physics object and the old source scene.
	for child: Node in _map.get_children():
		if String(child.name).begins_with("Boundary") and child is Node3D:
			(child as Node3D).visible=false
	for node: Node in _map.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		var path: String = String(_map.get_path_to(node))
		if path == "Ground/Mesh":
			visual.material_override=grass
		elif path.begins_with("OuterWall"):
			# The original low boundary boxes stay solid, but their visible caps
			# create a straight dark stripe well inside the camera view.
			visual.visible=false
		elif path.begins_with("Scenery/EdgeGround/") and visual.mesh is BoxMesh:
			# Perimeter slabs exist only to extend the visible terrain; they have no
			# collision. Replace their thick boxes with overlapping flat tops so
			# the camera cannot see a dark vertical side at the ground transition.
			var size: Vector3=(visual.mesh as BoxMesh).size
			var surface_mesh := PlaneMesh.new()
			surface_mesh.size=Vector2(size.x+.08,size.z+.08)
			surface_mesh.material=grass
			var surface := MeshInstance3D.new()
			surface.name="EdgeGroundSurface_%s"%visual.name
			surface.mesh=surface_mesh
			surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(surface)
			surface.global_position=Vector3(visual.global_position.x,.006,visual.global_position.z)
			visual.visible=false
		elif path.begins_with("PathArt") or path.begins_with("PathEast") or path.begins_with("PathGuild"):
			var bounds: AABB=visual.global_transform*visual.get_aabb()
			var center: Vector3=bounds.get_center()
			rectangles.append(Vector4(center.x,center.z,bounds.size.x*.5,bounds.size.z*.5))
			visual.visible=false
			original_roads.append(visual)
		elif visual.mesh is BoxMesh:
			var size: Vector3=(visual.mesh as BoxMesh).size
			# Expanded trails receive generated node names; match floor geometry.
			if size.y <= .021 and (size.x >= 3.4 or size.z >= 3.4):
				visual.visible=false
				original_roads.append(visual)
				rectangles.append(Vector4(visual.global_position.x,visual.global_position.z,size.x*.5,size.z*.5))
		# Local surface overrides, never mutate imported shared materials.
		if path.begins_with("Presentation/Border/"):
			# High polygon cliff crowns cast long sharp lines across the playable floor.
			visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface: int in visual.mesh.get_surface_count():
				var original: Material=visual.mesh.surface_get_material(surface)
				if original != null and original.resource_name == "ForestEarth":
					visual.set_surface_override_material(surface,grass)
		elif path.begins_with("Tree") or (visual.mesh != null and visual.mesh.resource_path.contains("round_tree")):
			var canopy_surfaces: PackedInt32Array = []
			for surface: int in visual.mesh.get_surface_count():
				var original: Material=visual.mesh.surface_get_material(surface)
				if original == null:continue
				if original.resource_name == "ForestEarth":
					visual.set_surface_override_material(surface,grass)
				elif original is StandardMaterial3D:
					var color: Color=(original as StandardMaterial3D).albedo_color
					if color.g > color.r*1.15 and color.g > color.b*1.05:
						var key: String=original.resource_name
						if not palette.has(key):
							var foliage := StandardMaterial3D.new()
							foliage.albedo_color=Color(.34,.48,.20) if key.contains("light") else Color(.22,.36,.14)
							foliage.roughness=.95
							palette[key]=foliage
						visual.set_surface_override_material(surface,palette[key])
						canopy_surfaces.append(surface)
			if not canopy_surfaces.is_empty():
				visual.set_meta(&"occlusion_canopy_surfaces", canopy_surfaces)
				visual.add_to_group(&"exploration_foliage_occluder")
	# Flatten presentation only. Physical ground and route dimensions stay intact.
	# One world-space material paints the union, so overlapping planes have the
	# same color and do not introduce grassy cross seams or raised side faces.
	if rectangles.size()>0 and rectangles.size()<=16:
		var trail := ShaderMaterial.new()
		trail.shader=load("res://assets/shaders/forest/trail.gdshader")
		trail.set_shader_parameter("trail_count",rectangles.size())
		var shader_rectangles: PackedVector4Array=rectangles.duplicate()
		shader_rectangles.resize(16)
		trail.set_shader_parameter("trail_rects",shader_rectangles)
		var ground := _map.get_node("Ground/Mesh") as MeshInstance3D
		var floor_bounds: AABB=ground.global_transform*ground.get_aabb()
		for i: int in rectangles.size():
			var rect: Vector4=rectangles[i]
			var plane := PlaneMesh.new()
			plane.size=Vector2(rect.z*2,rect.w*2)
			plane.subdivide_width=0
			plane.subdivide_depth=0
			plane.material=trail
			var surface := MeshInstance3D.new()
			surface.name="TrailSurface%d"%i
			surface.mesh=plane
			surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(surface)
			surface.global_position=Vector3(rect.x,floor_bounds.end.y+.005,rect.y)
	else:
		push_error("Forest presentation expected 1–16 road rectangles; keep original road artwork.")
		for original: MeshInstance3D in original_roads:original.visible=true
	var rng := RandomNumberGenerator.new()
	rng.seed=261026
	for asset: String in ["grass_a","bush_a","flower_a"]:
		var packed: PackedScene=load("res://assets/models/greystone/props/"+asset+".glb")
		var template: Node3D=packed.instantiate()
		var meshes: Array[Node]=template.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty():
			template.free()
			continue
		var source := meshes[0] as MeshInstance3D
		var transforms: Array[Transform3D]=[]
		for attempt: int in range(300 if asset=="grass_a" else 90):
			var p:=Vector3(rng.randf_range(-22,22),.025,rng.randf_range(-22,22))
			if not _off_road(p):continue
			var scale_value: float=rng.randf_range(.45,.85) if asset=="bush_a" else rng.randf_range(.55,1.05)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),p))
		var batch := MultiMeshInstance3D.new()
		batch.name=asset.to_pascal_case()+"Batch"
		batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=source.mesh
		batch.multimesh.instance_count=transforms.size()
		for i: int in transforms.size():batch.multimesh.set_instance_transform(i,transforms[i])
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		template.free()

func _off_road(p: Vector3) -> bool:
	if absf(p.z)<2.5 or (absf(p.x)<2.5 and absf(p.z)<11):return false
	if absf(absf(p.z)-17)<2.5 or absf(absf(p.x)-18)<2.5:return false
	for target: WorldInteractable in (_map as ExplorationMap).targets:
		if p.distance_to(target.position)<2.6:return false
	for marker: Node in _map.find_children("*","Marker3D",true,false):
		if p.distance_to((marker as Node3D).position)<2.6:return false
	return true
