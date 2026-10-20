extends SceneTree
## Licensed prop import, sharing and simplified collision in an isolated world.

const LOG_SCENE: PackedScene = preload("res://scenes/world/greystone/props/fallen_log.tscn")
const MODEL: String = "res://assets/models/environment/fallen_log.glb"
const OUT: String = "res://artifacts/free_environment_20261020/fallen_log"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUT + "/" + label + ".webp", true, 0.92) == OK, label + " captured")

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
	world.add_child(camera)
	var first := LOG_SCENE.instantiate() as Node3D
	world.add_child(first)
	var meshes: Array[Node] = first.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 1, "one reusable log mesh")
	var mesh := (meshes[0] as MeshInstance3D).mesh
	var triangles: int = 0
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var shared_materials: Array[String] = []
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		for point: Vector3 in vertices:
			_check(point.is_finite(), "finite source vertex")
			low = low.min(point)
			high = high.max(point)
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		_check(material != null and material.albedo_texture == null, "texture-free material")
		if material != null:
			shared_materials.append(material.resource_path)
			_check(material.resource_path in ["res://assets/materials/greystone/props/wood.tres", "res://assets/materials/greystone/props/wood_cut.tres"], "shared Greystone palette")
	_check(triangles == 268 and triangles <= 1000, "actual triangles and explicit budget")
	_check(absf(low.y) < 0.005 and absf(high.x-low.x-3.0) < 0.005, "ground-center pivot and 3m length")
	var shapes: Array[Node] = first.find_children("*", "CollisionShape3D", true, false)
	_check(shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is CapsuleShape3D, "single simplified trunk capsule")
	_check((shapes[0] as CollisionShape3D).scale.is_equal_approx(Vector3.ONE), "collision resource dimension without scaled shape")
	var copies: Array[Node3D] = []
	for index: int in range(2):
		var copy := LOG_SCENE.instantiate() as Node3D
		copy.position = Vector3((index*2-1)*4.1, 0, -2.5)
		copy.rotation.y = 0.35 if index == 0 else -0.4
		world.add_child(copy)
		copies.append(copy)
		var second_mesh := (copy.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		_check(second_mesh == mesh, "instances share imported mesh")
		for surface: int in range(mesh.get_surface_count()):
			_check(second_mesh.surface_get_material(surface) == mesh.surface_get_material(surface), "instances share material")
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var collision := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,0.44,2), Vector3(0,0.44,-2), 1))
	_check(not collision.is_empty() and collision.get("collider") == first.get_node("TrunkCollision"), "trunk blocks direct crossing")
	var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.1,0.44,2), Vector3(2.1,0.44,-2), 1))
	_check(clear.is_empty(), "side route remains clear")
	var above := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.3,2), Vector3(0,1.3,-2), 1))
	_check(above.is_empty(), "capsule has bounded height")
	var body := CharacterBody3D.new()
	var actor_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.6
	actor_shape.shape = capsule
	body.add_child(actor_shape)
	body.position = Vector3(0,0.8,2)
	world.add_child(body)
	await physics_frame
	for step: int in range(90):
		await physics_frame
		body.velocity = Vector3(0,0,-2)
		body.move_and_slide()
	_check(body.position.z > 0.50 and body.position.z < 0.85, "CharacterBody3D stops at trunk")
	body.position = Vector3(2.1,0.8,2)
	for step: int in range(90):
		await physics_frame
		body.velocity = Vector3(0,0,-2)
		body.move_and_slide()
	_check(body.position.z < -0.7, "CharacterBody3D can walk around")
	body.queue_free()
	camera.size = 12.5
	camera.position = Vector3(8,8,10)
	camera.look_at(Vector3(0,0.45,-1))
	await _capture("three_instances")
	for copy: Node3D in copies: copy.visible = false
	camera.size = 4.2
	camera.position = Vector3(3,2.5,4)
	camera.look_at(Vector3(0,0.55,0))
	await _capture("three_quarter")
	camera.position = Vector3(4,0.55,0)
	camera.look_at(Vector3(0,0.55,0))
	await _capture("cut_end")
	camera.position = Vector3(0,0.55,4)
	camera.look_at(Vector3(0,0.55,0))
	await _capture("front")
	var report: Dictionary = {"checks":checks,"failures":failures,"model_sha256":FileAccess.get_sha256(MODEL),
		"triangles_each":triangles,"budget":1000,"bounds":[low,high],"materials":shared_materials,
		"instances":3,"shared_mesh":true,"collision":"single capsule; rays and actual CharacterBody3D motion",
		"graphical":true,"physical_input":false,"formal_forest_placement":false,"performance_benchmark":false}
	var file := FileAccess.open(OUT + "/godot_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("FOREST_LOG_TEST ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
