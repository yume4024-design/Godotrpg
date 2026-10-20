extends SceneTree
## New character surface only; explicitly no skeleton, actions or gameplay QA.

var model_path: String = "res://assets/models/rebuilt_characters/ren_static.glb"
var asset_id: String = "ren"
var category: String = "player_character"
var height: float = 1.95
var checks: int = 0
var failures: Array[String] = []
var output: String
const Budget = preload("res://scripts/tools/asset_budget_policy.gd")

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--model="): model_path = argument.trim_prefix("--model=")
		if argument.begins_with("--id="): asset_id = argument.trim_prefix("--id=")
		if argument.begins_with("--height="): height = argument.trim_prefix("--height=").to_float()
		if argument.begins_with("--category="): category = argument.trim_prefix("--category=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty(): output = "res://artifacts/character_rebuild_20261020/" + asset_id + "/godot_static"
	if "--portrait" in OS.get_cmdline_user_args(): root.size = Vector2i(900, 900)
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(output + "/" + name + ".webp", true, 0.92) == OK, name + " captured")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("34434e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height * 1.16
	camera.position = Vector3(0, height * 0.5, height * 3)
	world.add_child(camera)
	camera.look_at(Vector3(0, height * 0.5, 0))
	var pivot := Node3D.new()
	world.add_child(pivot)
	var packed := load(model_path) as PackedScene
	_check(packed != null, "surface GLB imports")
	if packed == null:
		quit(1)
		return
	var model := packed.instantiate() as Node3D
	pivot.add_child(model)
	await process_frame
	var triangles: int = 0
	var textures: Array[Vector2i] = []
	var finite: bool = true
	var lowest: float = INF
	var highest: float = -INF
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		_check(instance.skin == null, "static status disclosed")
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			for point: Vector3 in vertices:
				var transformed: Vector3 = instance.global_transform * point
				finite = finite and transformed.is_finite()
				lowest = minf(lowest, transformed.y)
				highest = maxf(highest, transformed.y)
			_check(arrays[Mesh.ARRAY_TEX_UV] != null and not (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty(), "UV retained")
			var material := instance.get_active_material(surface) as StandardMaterial3D
			_check(material != null and material.albedo_texture != null, "repaired albedo imported")
			if material != null and material.albedo_texture != null:
				textures.append(Vector2i(material.albedo_texture.get_size()))
				_check(not material.normal_enabled, "diagnosed normal map disabled in candidate")
	_check(finite and absf(lowest) < 0.01 and absf(highest - height) < 0.01, "finite normalized ground/height")
	_check(Budget.within_budget(triangles, category), category + " triangle budget")
	_check(model.find_children("*", "Skeleton3D", true, false).is_empty(), "no rig completion claimed")
	for view: int in range(4):
		pivot.rotation.y = view * PI / 2.0
		await _capture("body_" + str(view))
	camera.size = height * 0.35
	camera.position.y = height * 0.87
	camera.look_at(Vector3(0, height * 0.87, 0))
	for view: int in range(4):
		pivot.rotation.y = view * PI / 2.0
		await _capture("head_" + str(view))
	pivot.rotation.y = PI / 4.0
	await _capture("head_three_quarter")
	model.free()
	model = packed.instantiate() as Node3D
	pivot.add_child(model)
	await process_frame
	_check(not model.find_children("*", "MeshInstance3D", true, false).is_empty(), "reinstantiate retains model")
	var report: Dictionary = {"asset": asset_id, "model": model_path, "model_sha256": FileAccess.get_sha256(model_path),
		"checks": checks, "failures": failures, "triangles": triangles, "category": category,
		"textures": textures, "height_range": [lowest, highest], "graphical": true,
		"rigged": false, "animation_tested": false, "formal_gameplay": false, "physical_input": false}
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("STATIC_CHARACTER_REVIEW ", asset_id, " ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
