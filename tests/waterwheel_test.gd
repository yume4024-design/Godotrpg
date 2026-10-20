extends SceneTree
## Actual graphical prop import/rotation/material checks; not a map/FPS test.

const PROP: PackedScene = preload("res://scenes/world/greystone/props/waterwheel.tscn")
const MODEL: String = "res://assets/models/greystone/props/waterwheel.glb"
const OUT: String = "res://artifacts/environment_rebuild_20261020/waterwheel"
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
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -25, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	world.add_child(camera)
	var prop := PROP.instantiate() as Node3D
	var other := PROP.instantiate() as Node3D
	world.add_child(prop)
	world.add_child(other)
	prop.set_process(false)
	other.set_process(false)
	other.visible = false
	await process_frame
	var wheel := prop.find_child("Wheel", true, false) as Node3D
	var other_wheel := other.find_child("Wheel", true, false) as Node3D
	var axle := prop.find_child("FixedAxle", true, false) as Node3D
	_check(wheel != null and axle != null and other_wheel != null, "imported independent wheel and fixed axle")
	if wheel == null or axle == null or other_wheel == null:
		quit(1)
		return
	var meshes: Array[Node] = prop.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "two reusable mesh parts")
	var triangles: int = 0
	var surfaces: int = 0
	var finite: bool = true
	var material_paths: Dictionary = {}
	for child: Node in meshes:
		var mesh := (child as MeshInstance3D).mesh
		for surface: int in range(mesh.get_surface_count()):
			surfaces += 1
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			for point: Vector3 in vertices:
				finite = finite and point.is_finite()
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			_check(material != null and material.albedo_texture == null, "texture-free material")
			if material != null:
				material_paths[material.resource_path] = true
				_check(material.resource_path.begins_with("res://assets/materials/greystone/props/"), "existing shared G04 material")
	_check(triangles == 1212 and triangles <= 2500, "explicit prop triangle budget")
	_check(finite, "finite imported geometry")
	_check(material_paths.size() == 3 and surfaces == 4, "three shared materials across four surfaces")
	_check(prop.find_children("*", "CollisionObject3D", true, false).is_empty(), "decorative no-collision contract")
	var fixed_pose: Transform3D = axle.transform
	var root_pose: Transform3D = prop.transform
	var start: Transform3D = wheel.transform
	prop.call("_process", 1.0)
	_check(not wheel.transform.is_equal_approx(start), "wheel turns")
	_check(other_wheel.transform.is_equal_approx(start), "second instance motion independent")
	_check(axle.transform.is_equal_approx(fixed_pose) and prop.transform.is_equal_approx(root_pose), "axle and placement remain fixed")
	prop.set("running", false)
	var stopped: Transform3D = wheel.transform
	prop.call("_process", 1.0)
	_check(wheel.transform.is_equal_approx(stopped), "stop freezes wheel")
	prop.set("running", true)
	wheel.rotation.x = 0.0
	for step: int in range(192):
		prop.call("_process", 8.0 / 192.0)
	_check(wheel.transform.is_equal_approx(start), "full eight-second revolution returns to start")
	var views: Dictionary = {"three_quarter": Vector3(6, 3, 5), "outer_side": Vector3(6, 0, 0), "inner_side": Vector3(-6, 0, 0), "edge": Vector3(0, 0, 6)}
	for label: String in views:
		camera.position = views[label]
		camera.look_at(Vector3.ZERO)
		await _capture(label)
	camera.position = Vector3(6, 2, 4)
	camera.look_at(Vector3.ZERO)
	prop.call("_process", 1.0)
	await _capture("turn_eighth")
	prop.call("_process", 1.0)
	await _capture("turn_quarter")
	prop.free()
	other.free()
	prop = PROP.instantiate() as Node3D
	world.add_child(prop)
	await process_frame
	_check(prop.find_child("Wheel", true, false) != null, "reinstantiate retains wheel")
	var report: Dictionary = {"checks": checks, "failures": failures, "model_sha256": FileAccess.get_sha256(MODEL),
		"triangles": triangles, "budget": 2500, "meshes": meshes.size(), "surfaces": surfaces,
		"shared_materials": material_paths.keys(), "graphical": true, "rotation_simulated_seconds": 10.0,
		"formal_village_replacement": false, "physical_input": false, "performance_benchmark": false}
	var file := FileAccess.open(OUT + "/godot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WATERWHEEL_TEST ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
