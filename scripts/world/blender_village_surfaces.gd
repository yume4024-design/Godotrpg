@tool
extends Node
## Candidate-only shared materials; never edits imported Mesh or base material data.
@export var village: Node3D
const GRASS: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/grass.tres")
const EARTH: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/earth.tres")
const ROCK: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/rock.tres")
const RIVER: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/river.tres")
const LAKE: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/lake.tres")
const FALL: ShaderMaterial = preload("res://assets/materials/greystone/blender_surface/waterfall.tres")

func _ready() -> void:
	if not is_instance_valid(village): return
	for node: Node in village.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var path: String = str(village.get_path_to(mesh))
		if path.begins_with("Terrain/"):
			mesh.material_override = GRASS if "Grass" in mesh.name else ROCK
		elif path.begins_with("Paths/"):
			mesh.material_override = ROCK if "Steps" in mesh.name else EARTH
		elif path.begins_with("Cliffs/") or (path.begins_with("Mine/") and ("Cliff" in mesh.name or "Rock" in mesh.name)):
			mesh.material_override = ROCK
		elif path.begins_with("Water/"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override = ROCK if "_Bed" in mesh.name else (FALL if "Waterfall" in mesh.name else (LAKE if "Lake" in mesh.name else RIVER))
		elif path.begins_with("Props/"):
			for index: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.mesh.surface_get_material(index)
				# GreystoneRef_oak also contains "stone" in the project prefix.
				# Match the material token, preserving timber, iron and window surfaces.
				if material and (material.resource_name.to_lower().begins_with("stone") or "_stone" in material.resource_name.to_lower()):
					mesh.set_surface_override_material(index, ROCK)
			if "FarmBed" in mesh.name: mesh.material_override = EARTH
