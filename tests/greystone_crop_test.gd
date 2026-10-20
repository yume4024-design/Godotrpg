extends SceneTree
## Crop instancing/import/silhouette evidence; no crop economy or save system.

const CROP: PackedScene = preload("res://scenes/world/greystone/props/leafy_crop.tscn")
const MODEL: String = "res://assets/models/greystone/props/leafy_crop.glb"
const OUT: String = "res://artifacts/environment_rebuild_20261020/leafy_crop"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUT + "/" + name + ".webp", true, 0.92) == OK, name + " captured")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -25, 0)
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	var crops: Array[Node3D] = []
	var shared: Mesh
	var total_triangles: int = 0
	var largest_instance: int = 0
	var all_shared: bool = true
	var finite: bool = true
	var shared_materials: Dictionary = {}
	for index: int in range(28):
		var crop := CROP.instantiate() as Node3D
		crop.position = Vector3((index % 7) * 0.9, 0, (index / 7) * 0.9)
		world.add_child(crop)
		crops.append(crop)
		var meshes: Array[Node] = crop.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() == 1, "single crop mesh")
		_check(crop.find_children("*", "CollisionObject3D", true, false).is_empty(), "decorative crop collision contract")
		var instance_triangles: int = 0
		for child: Node in meshes:
			var mesh := (child as MeshInstance3D).mesh
			if shared == null:
				shared = mesh
			else:
				all_shared = all_shared and mesh == shared
			for surface: int in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				instance_triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				for point: Vector3 in vertices:
					finite = finite and point.is_finite() and point.y >= -0.005 and point.y <= 0.61
				var material := mesh.surface_get_material(surface) as StandardMaterial3D
				_check(material != null and material.albedo_texture == null, "texture-free leaf material")
				if material != null:
					shared_materials[material.resource_path] = true
					_check(material.resource_path.begins_with("res://assets/materials/greystone/props/leaf"), "existing shared leaf material")
		_check(instance_triangles > 0 and instance_triangles <= 300, "explicit crop budget")
		largest_instance = maxi(largest_instance, instance_triangles)
		total_triangles += instance_triangles
	_check(all_shared, "all 28 instances share the same imported Mesh resource")
	_check(finite, "finite geometry and original placeholder height envelope")
	_check(shared_materials.size() == 2, "two shared leaf palette materials")
	_check(total_triangles <= 8400, "28-instance triangle ceiling")
	camera.size = 7.2
	camera.position = Vector3(8, 6, 8)
	camera.look_at(Vector3(2.7, 0.2, 1.35))
	await _capture("plot_28")
	for index: int in range(1, crops.size()):
		crops[index].visible = false
	camera.size = 1.0
	camera.position = Vector3(1.1, 0.85, 1.3)
	camera.look_at(Vector3(0, 0.30, 0))
	await _capture("three_quarter")
	camera.position = Vector3(0, 0.30, 1.5)
	camera.look_at(Vector3(0, 0.30, 0))
	await _capture("front")
	camera.position = Vector3(0, 1.7, 0)
	camera.look_at(Vector3(0, 0.30, 0), Vector3.FORWARD)
	await _capture("top")
	var report: Dictionary = {"checks": checks, "failures": failures, "model_sha256": FileAccess.get_sha256(MODEL),
		"instances": crops.size(), "triangles_each": largest_instance, "total_visible_triangles": total_triangles,
		"shared_mesh": all_shared, "shared_materials": shared_materials.keys(), "graphical": true,
		"formal_village_replacement": false, "physical_input": false, "performance_benchmark": false}
	var file := FileAccess.open(OUT + "/godot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GREYSTONE_CROP_TEST ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
