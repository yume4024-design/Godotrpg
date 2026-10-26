@tool
extends Node
## Candidate-only shared materials; never edits imported Mesh or base material data.
@export var village: Node3D
const GRASS: ShaderMaterial = preload("res://assets/materials/greystone/reference_v5/grass.tres")
const EARTH: ShaderMaterial = preload("res://assets/materials/greystone/reference_v5/earth.tres")
const ROCK: ShaderMaterial = preload("res://assets/materials/greystone/reference_v5/rock.tres")
const RIVER: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/river.tres")
const LAKE: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/lake.tres")
const FALL: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/waterfall.tres")
const FLAME: Shader = preload("res://assets/shaders/mine/flame.gdshader")
const FALL_STREAM: Shader = preload("res://assets/shaders/greystone/reference_fall.gdshader")
const FOAM: Shader = preload("res://assets/shaders/greystone/reference_foam.gdshader")
const TIMBER: Shader = preload("res://assets/shaders/mine/wood.gdshader")

func _ready() -> void:
	if not is_instance_valid(village): return
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(.69,.85,.84)
	foam.roughness = .8
	var flame := ShaderMaterial.new()
	flame.shader = FLAME
	var falling := ShaderMaterial.new()
	falling.shader = FALL_STREAM
	var pool_foam := ShaderMaterial.new()
	pool_foam.shader = FOAM
	var wake_foam: ShaderMaterial = pool_foam.duplicate()
	wake_foam.set_shader_parameter("rock_wake", true)
	var timber := ShaderMaterial.new()
	timber.shader = TIMBER
	timber.set_shader_parameter("base_color", Color(.48,.31,.16))
	var lantern := StandardMaterial3D.new()
	lantern.albedo_color = Color(1.0,.62,.20)
	lantern.emission_enabled = true
	lantern.emission = Color(1.0,.38,.07)
	lantern.emission_energy_multiplier = .7
	lantern.roughness = .65
	var masonry: ShaderMaterial = ROCK.duplicate()
	masonry.set_shader_parameter("masonry_joints", true)
	for node: Node in village.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var path: String = str(village.get_path_to(mesh))
		if path.begins_with("Terrain/"):
			mesh.material_override = GRASS if "Grass" in mesh.name else ROCK
		elif path.begins_with("Paths/"):
			var is_masonry: bool = "Steps" in mesh.name and not "Approach" in mesh.name
			mesh.material_override = masonry if is_masonry else EARTH
			# Thin soil overlays should not cast a dark ribbon onto the terrain.
			if not is_masonry:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mesh.name == &"VillageClearing":
				_apply_clearing_verge(mesh)
		elif path.begins_with("Cliffs/") or (path.begins_with("Mine/") and ("Cliff" in mesh.name or "Rock" in mesh.name)):
			if mesh.name.begins_with("NaturalRimGrass_"):
				mesh.material_override = GRASS
			elif mesh.name.begins_with("NaturalRimSoil_"):
				mesh.material_override = EARTH
			else:
				mesh.material_override = ROCK
		elif path.begins_with("Water/"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override = foam if "FoamSplash" in mesh.name else (ROCK if "_Bed" in mesh.name else (FALL if "Waterfall" in mesh.name else (LAKE if "Lake" in mesh.name else RIVER)))
			if "Waterfall" in mesh.name: mesh.material_override = falling
			if mesh.name == &"CascadeFoamPool": mesh.material_override = pool_foam
			if mesh.name == &"CascadeFoamBillows": mesh.material_override = foam
			if mesh.name == &"RiverStoneWakes": mesh.material_override = wake_foam
		elif path.begins_with("Vegetation/") and ("Stone" in mesh.name or "Rock" in mesh.name):
			mesh.material_override = ROCK
		elif path.begins_with("Buildings_Candidate/"):
			for index: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.mesh.surface_get_material(index)
				if material and (material.resource_name.begins_with("ReferenceRoof_") or material.resource_name.begins_with("ReferenceFacade_")) and material.resource_name.ends_with("_glass"):
					mesh.set_surface_override_material(index, lantern)
				elif material and material.resource_name == "ReferenceFacade_stone":
					# Blender's procedural stone graph is not encoded by glTF.
					mesh.set_surface_override_material(index, ROCK)
		elif path.begins_with("Mine/") and "TorchFlame" in mesh.name:
			mesh.material_override = flame
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var light := OmniLight3D.new()
			light.light_color = Color(1,.55,.18)
			light.light_energy = 1.0
			light.omni_range = 4.5
			light.shadow_enabled = false
			mesh.add_child(light)
		elif path.begins_with("Props/") or path.begins_with("Mine/"):
			for index: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.mesh.surface_get_material(index)
				# GreystoneRef_oak also contains "stone" in the project prefix.
				# Match the material token, preserving timber, iron and window surfaces.
				if material and (material.resource_name.to_lower().begins_with("stone") or "_stone" in material.resource_name.to_lower()):
					mesh.set_surface_override_material(index, ROCK)
				elif material and ("wood" in material.resource_name.to_lower() or "_oak" in material.resource_name.to_lower()):
					mesh.set_surface_override_material(index, timber)
				elif material and "_warm" in material.resource_name.to_lower() and mesh.name.begins_with("Lantern"):
					mesh.set_surface_override_material(index, lantern)
					_add_lantern_light(mesh, index)
			if "FarmBed" in mesh.name: mesh.material_override = EARTH

func _add_lantern_light(mesh: MeshInstance3D, surface: int) -> void:
	var arrays: Array = mesh.mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty(): return
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for point: Vector3 in vertices: bounds = bounds.expand(point)
	var lamp := OmniLight3D.new()
	lamp.name = "LanternFill"
	lamp.position = bounds.get_center()
	lamp.light_color = Color(1.0,.65,.28)
	lamp.light_energy = .55
	lamp.light_specular = .1
	lamp.omni_range = 3.5
	lamp.shadow_enabled = false
	mesh.add_child(lamp)

func _apply_clearing_verge(mesh: MeshInstance3D) -> void:
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var edges: Dictionary = {}
	for index: int in range(0, faces.size(), 3):
		for corner: int in 3:
			var a: Vector3 = mesh.to_global(faces[index+corner]).snapped(Vector3.ONE*.0001)
			var b: Vector3 = mesh.to_global(faces[index+(corner+1)%3]).snapped(Vector3.ONE*.0001)
			var pair: Array[String] = [str(a), str(b)]
			pair.sort()
			var key: String = pair[0]+"|"+pair[1]
			if edges.has(key): edges[key]["count"] += 1
			else: edges[key] = {"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"count":1}
	var starts := PackedVector2Array()
	var ends := PackedVector2Array()
	for edge: Dictionary in edges.values():
		if edge.count == 1:
			starts.append(edge.a)
			ends.append(edge.b)
	if starts.is_empty() or starts.size()>32:
		push_error("Village clearing boundary exceeds the authored shader budget")
		return
	var count: int = starts.size()
	starts.resize(32)
	ends.resize(32)
	var clearing: ShaderMaterial = EARTH.duplicate()
	clearing.set_shader_parameter("clearing_edge_count", count)
	# Only the large clearing gains a broader grass verge; intersecting paths
	# retain their full soil width and all collision geometry stays unchanged.
	clearing.set_shader_parameter("clearing_verge_width", 3.0)
	clearing.set_shader_parameter("clearing_edge_start", starts)
	clearing.set_shader_parameter("clearing_edge_end", ends)
	mesh.material_override = clearing
