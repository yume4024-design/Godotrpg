extends Node3D
## Explicit simplified colliders are authored with the Blender layout, not guessed.
const ROCK: Shader = preload("res://assets/shaders/greystone/rock.gdshader")
const EARTH: Shader = preload("res://assets/shaders/greystone/ground.gdshader")
const WATER: Shader = preload("res://assets/shaders/greystone/water.gdshader")
const WOOD: Shader = preload("res://assets/shaders/mine/wood.gdshader")
const FLAME: Shader = preload("res://assets/shaders/mine/flame.gdshader")
var _shared: Dictionary = {}
@export var build_collisions: bool = true

func _ready() -> void:
	if build_collisions: _build_collision()
	_apply_surfaces()

func _build_collision() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/mine_reference/manifest.json"))
	var body := StaticBody3D.new()
	body.name = "AuthoredCollision"
	add_child(body)
	for row: Dictionary in manifest.collisions:
		var collision := CollisionShape3D.new()
		collision.name = row.name
		if row.type == "box":
			var shape := BoxShape3D.new()
			shape.size = _vector(row.size)
			collision.shape = shape
			collision.position = _vector(row.position)
			collision.rotation.y = float(row.rotation)
		else:
			var shape := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for point: Array in row.points: points.append(_vector(point))
			shape.points = points
			collision.shape = shape
		body.add_child(collision)

func _apply_surfaces() -> void:
	for node: Node in find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		for index: int in visual.mesh.get_surface_count():
			var original: Material = visual.mesh.surface_get_material(index)
			if original == null: continue
			var name_key: String = original.resource_name
			if name_key.begins_with("Mine_Rock") or name_key.begins_with("Mine_Earth") or name_key.begins_with("Mine_Water") or name_key.begins_with("Mine_Fall") or name_key.begins_with("Mine_Wood") or name_key.begins_with("Mine_Flame"):
				visual.set_surface_override_material(index,_material(name_key))
			elif "crystal" in name_key.to_lower() and original is StandardMaterial3D:
				var emissive := original.duplicate() as StandardMaterial3D
				emissive.emission_enabled = true
				emissive.emission = Color(.05,.35,.85)
				emissive.emission_energy_multiplier = 1.3
				visual.set_surface_override_material(index,emissive)

func _vector(array: Array) -> Vector3:
	return Vector3(float(array[0]),float(array[1]),float(array[2]))

func _material(key: String) -> ShaderMaterial:
	if _shared.has(key): return _shared[key]
	var material := ShaderMaterial.new()
	if key.begins_with("Mine_Flame"):
		material.shader = FLAME
	elif key.begins_with("Mine_Wood"):
		material.shader = WOOD
		material.set_shader_parameter("base_color",Color(.56,.36,.18) if key.begins_with("Mine_WoodLight") else Color(.40,.25,.12))
	elif key.begins_with("Mine_Rock"):
		material.shader = ROCK
		material.set_shader_parameter("base_color",Color(.37,.40,.46))
		material.set_shader_parameter("moss_color",Color(.27,.36,.38))
	elif key.begins_with("Mine_Earth"):
		material.shader = EARTH
		material.set_shader_parameter("base_color",Color(.63,.48,.29))
		material.set_shader_parameter("grain_color",Color(.78,.64,.41))
		material.set_shader_parameter("grass_amount",0.0)
	else:
		material.shader = WATER
		material.set_shader_parameter("shallow_color",Color(.12,.53,.80))
		material.set_shader_parameter("deep_color",Color(.03,.18,.39))
		material.set_shader_parameter("falling",1.0 if key.begins_with("Mine_Fall") else 0.0)
	_shared[key] = material
	return material
