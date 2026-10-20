extends SceneTree
## Measures imported geometry in metres; screenshots use the real village.
var output: String = "res://artifacts/locomotion/revised"

func _initialize() -> void:
	_run.call_deferred()

func bounds(node: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	var village: Node3D = load("res://scenes/world/greystone_runtime.tscn").instantiate()
	root.add_child(village)
	var actor: Node3D = load("res://scenes/characters/ren_pixal_visual.tscn").instantiate()
	actor.scale = Vector3.ONE
	actor.position = Vector3(-22, 2, -12)
	root.add_child(actor)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	camera.position = actor.position + Vector3(16, 18, 20)
	camera.look_at(actor.position + Vector3(0, 2, -2))
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .6
	root.add_child(env)
	await create_timer(.3).timeout
	var report: Dictionary = {"hero_size_m": str(bounds(actor).size), "hero_height_m": bounds(actor).size.y, "buildings": {}, "npcs": {}}
	for building: Node3D in village.get_node("Village/Buildings").get_children():
		report.buildings[building.name] = {"size_m": str(bounds(building).size), "door_width_m": building.get_node("DoorApproach").get_meta("door_width_m")}
	for npc: Node3D in village.get_node("NPCs").get_children():
		report.npcs[npc.name] = {"height_m": bounds(npc).size.y}
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(output + "/village.webp")
	var file: FileAccess = FileAccess.open(output + "/dimensions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
