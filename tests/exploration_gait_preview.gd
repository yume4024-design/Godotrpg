extends SceneTree
## Render actual imported gaits at their physical travel cadence for visual review.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output: String = "res://artifacts/locomotion/preview"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(900, 650)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var actors: Array[CartoonActor] = []
	for character: String in ["ren", "lia"]:
		var actor: CartoonActor = load("res://scenes/characters/%s_pixal_visual.tscn" % character).instantiate()
		stage.add_child(actor)
		actor.position.x = -.65 if character == "ren" else .65
		actor.rotation.y = -.4 if character == "ren" else .35
		actor.set_process(false)
		actors.append(actor)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(20, 20)
	stage.add_child(floor_mesh)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("#718779")
	floor_mesh.material_override = material
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(0, 1.9, 5)
	camera.look_at(Vector3(0, 1, 0))
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = .6
	sun.shadow_enabled = true
	stage.add_child(sun)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#718779")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .5
	stage.add_child(environment)
	for clip: String in ["walk", "run"]:
		for actor: CartoonActor in actors:
			actor.set_motion(.4 if clip == "walk" else 1)
			actor.call("set_travel_speed", 1.8 if clip == "walk" else 4.5)
		for frame: int in range(30):
			for actor: CartoonActor in actors: actor._process(1.0 / 15)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + "/%s_%02d.png" % [clip, frame])
		for actor: CartoonActor in actors:
			actor.set_motion(0)
			for frame: int in range(20): actor._process(1.0 / 60)
	print("GAIT_PREVIEW_CAPTURED actual imported walk/run; 30 frames each, 15 fps")
	quit()
