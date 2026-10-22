extends SceneTree
## Development-only composition inventory. This does not measure rendering or
## qualify assets. Instantiate real maps, including their additive _ready work.

const MAPS: Dictionary = {
	"greystone_runtime": "res://scenes/world/greystone_runtime.tscn",
	"forest": "res://scenes/world/expanded/forest.tscn",
	"mine": "res://scenes/world/expanded/mine.tscn",
}
var _mesh_cache: Dictionary = {}
var _models: Dictionary = {}
var _textures: Dictionary = {}
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _mesh_info(mesh: Mesh) -> Dictionary:
	var identity: int = mesh.get_instance_id()
	if not _mesh_cache.has(identity):
		var result: Dictionary = {"class": mesh.get_class(), "resource": mesh.resource_path,
			"triangles": mesh.get_faces().size()/3, "surfaces": mesh.get_surface_count()}
		if mesh is BoxMesh: result["box_size"] = _vector(mesh.size)
		_mesh_cache[identity] = result
	return _mesh_cache[identity]

func _material_info(material: Material) -> Dictionary:
	if material == null: return {"class": "None"}
	var info: Dictionary = {"class": material.get_class(), "resource": material.resource_path}
	if material is StandardMaterial3D:
		info["albedo"] = [material.albedo_color.r,material.albedo_color.g,material.albedo_color.b,material.albedo_color.a]
		info["transparency"] = material.transparency
		info["has_albedo_texture"] = material.albedo_texture != null
		if material.albedo_texture != null:
			var path: String = material.albedo_texture.resource_path
			info["albedo_texture"] = path
			if FileAccess.file_exists(path) and not _textures.has(path):
				_textures[path] = FileAccess.get_sha256(path)
	return info

func _scan(node: Node, map: Node3D, rows: Dictionary, model: String = "", category: String = "environment", scenes: Array[String] = []) -> void:
	if node is CartoonActor: category = "character"
	var stack: Array[String] = scenes.duplicate()
	if not node.scene_file_path.is_empty():
		stack.append(node.scene_file_path)
		if node.scene_file_path.get_extension() in ["glb","gltf"]:
			model = node.scene_file_path
			if not _models.has(model):
				_models[model] = {"sha256": FileAccess.get_sha256(model), "bytes": FileAccess.open(model,FileAccess.READ).get_length()}
			rows.model_roots.append({"node": str(map.get_path_to(node)), "source": model, "category": category})
	if node is WorldInteractable:
		if node.kind in ["npc","battle"]: category = "character"
		rows.interactables.append({"node":str(map.get_path_to(node)),"id":str(node.interaction_id),
			"kind":node.kind,"position":_vector(node.global_position)})
	if node is MeshInstance3D and node.mesh != null:
		var materials: Array[Dictionary] = []
		for surface: int in range(node.mesh.get_surface_count()):
			materials.append(_material_info(node.get_active_material(surface)))
		rows.meshes.append({"node":str(map.get_path_to(node)),"model":model,"category":category,
			"scenes":stack,"mesh":_mesh_info(node.mesh),"materials":materials,
			"visible_in_tree":node.is_visible_in_tree(),"cast_shadow":node.cast_shadow,
			"position":_vector(node.global_position),"scale":_vector(node.global_basis.get_scale())})
	if node is CollisionShape3D and node.shape != null:
		var collision: Dictionary = {"node":str(map.get_path_to(node)),"class":node.shape.get_class(),
			"disabled":node.disabled,"position":_vector(node.global_position),"category":category}
		if node.shape is BoxShape3D: collision["box_size"] = _vector(node.shape.size)
		rows.collisions.append(collision)
	for child: Node in node.get_children():
		_scan(child,map,rows,model,category,stack)

func _totals(rows: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for category: String in ["environment","character"]:
		var meshes: int = 0
		var triangles: int = 0
		var primitives: int = 0
		var native_arrays: int = 0
		var unmodeled: Array[String] = []
		var sources: Dictionary = {}
		for row: Dictionary in rows.meshes:
			if row.category != category: continue
			meshes += 1
			triangles += int(row.mesh.triangles)
			if not row.model.is_empty(): sources[row.model] = true
			elif row.mesh["class"] != "ArrayMesh":
				primitives += 1
				unmodeled.append(row.node)
			else:
				native_arrays += 1
		result[category] = {"mesh_instances":meshes,"triangle_instances":triangles,
			"native_primitive_instances":primitives,"native_primitive_nodes":unmodeled,
			"array_mesh_instances_without_glb_ancestor":native_arrays,
			"distinct_glb_sources":sources.keys()}
	return result

func _item_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name: String in DirAccess.get_files_at("res://data/items"):
		if not name.ends_with(".tres"): continue
		var path: String = "res://data/items/"+name
		var definition: ItemDefinition = load(path) as ItemDefinition
		if definition == null or definition.id.is_empty():
			_failures.append("Invalid existing item definition: "+path)
			continue
		result.append({"source":path,"sha256":FileAccess.get_sha256(path),"id":str(definition.id),
			"name":definition.display_name,"slot":definition.slot})
	return result

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Specify a new output under this project's artifacts directory.")
		quit(1)
		return
	var output: String = ProjectSettings.globalize_path(args[0]).replace("\\","/").simplify_path()
	var allowed: String = ProjectSettings.globalize_path("res://artifacts/").replace("\\","/")
	if not output.begins_with(allowed) or FileAccess.file_exists(output):
		push_error("Preserve existing inventories; output must be a new artifact file.")
		quit(1)
		return
	var maps: Dictionary = {}
	for id: String in MAPS:
		var scene: PackedScene = load(MAPS[id])
		var map: Node3D = scene.instantiate()
		root.add_child(map)
		await process_frame
		await physics_frame
		var rows: Dictionary = {"scene":MAPS[id],"source_sha256":FileAccess.get_sha256(MAPS[id]),
			"model_roots":[],"meshes":[],"collisions":[],"interactables":[]}
		_scan(map,map,rows)
		rows["totals"] = _totals(rows)
		maps[id] = rows
		if str(map.get("map_id")) != id: _failures.append("Map identity mismatch: "+id)
		if rows.meshes.is_empty() or rows.collisions.is_empty(): _failures.append("Incomplete composition: "+id)
		print("WORLD_INVENTORY_MAP ",id," ",JSON.stringify(rows.totals))
		map.queue_free()
		await process_frame
		# Mesh IDs may be recycled after disposal; never retain the cache across maps.
		_mesh_cache.clear()
	var provenance: Dictionary = {}
	for path: String in ["res://scripts/core/greystone_integration.gd","res://scripts/world/expanded_wilderness.gd"]:
		provenance[path] = FileAccess.get_sha256(path)
	var report: Dictionary = {"schema_version":1,"engine":Engine.get_version_info().string,
		"display":DisplayServer.get_name(),"maps":maps,"model_files":_models,"texture_files":_textures,
		"source_files":provenance,"item_definitions":_item_definitions(),
		"failures":_failures,"method":"Actual standalone map instantiation including additive _ready geometry, without Player or the main game's post-load adapters; environment and NPC/enemy visuals separated. Composition only, not visual, collision-route, LOD, FPS or asset-quality acceptance. Visibility is tree state, not camera culling. Includes all instantiated geometry, not only visible triangles. Item definitions are data only; no inference that each has a world model."}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORLD_INVENTORY_RESULT maps=",maps.size()," models=",_models.size()," failures=",_failures.size())
	await create_timer(.2).timeout
	quit(0 if _failures.is_empty() else 1)
