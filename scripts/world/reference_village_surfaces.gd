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
	var timber := ShaderMaterial.new()
	timber.shader = TIMBER
	timber.set_shader_parameter("base_color", Color(.48,.31,.16))
	for node: Node in village.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var path: String = str(village.get_path_to(mesh))
		if path.begins_with("Terrain/"):
			mesh.material_override = GRASS if "Grass" in mesh.name else ROCK
		elif path.begins_with("Paths/"):
			var masonry: bool = "Steps" in mesh.name and not "Approach" in mesh.name
			mesh.material_override = ROCK if masonry else EARTH
			# Thin soil overlays should not cast a dark ribbon onto the terrain.
			if not masonry:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif path.begins_with("Cliffs/") or (path.begins_with("Mine/") and ("Cliff" in mesh.name or "Rock" in mesh.name)):
			mesh.material_override = ROCK
		elif path.begins_with("Water/"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override = foam if "FoamSplash" in mesh.name else (ROCK if "_Bed" in mesh.name else (FALL if "Waterfall" in mesh.name else (LAKE if "Lake" in mesh.name else RIVER)))
			if "Waterfall" in mesh.name: mesh.material_override = falling
			if "UpperRiver" in mesh.name:
				var upper: ShaderMaterial = falling.duplicate()
				upper.set_shader_parameter("horizontal", true)
				mesh.material_override = upper
		elif path.begins_with("Vegetation/") and ("Stone" in mesh.name or "Rock" in mesh.name):
			mesh.material_override = ROCK
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
			if "FarmBed" in mesh.name: mesh.material_override = EARTH
