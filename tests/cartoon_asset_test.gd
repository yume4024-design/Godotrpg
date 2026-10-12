extends SceneTree
## Inspect the exported assets inside Godot, including articulated presentation.
const ASSETS: Array[String] = ["ren", "lia", "guildmaster", "slime", "guardian"]
const LABELS: Array[String] = ["雷恩", "莉雅", "公會長", "森林史萊姆", "腐化守衛"]
var checks: int = 0
var failures: int = 0
var actors: Array[CartoonActor] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.title = "失落星核 — 卡通造型展示"
	var studio: Node3D = Node3D.new()
	root.add_child(studio)
	current_scene = studio
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#1d303d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#becbd5")
	environment.environment.ambient_light_energy = 0.65
	studio.add_child(environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("#fff2dc")
	key.light_energy = 1.1
	key.shadow_enabled = true
	studio.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#badcf4")
	studio.add_child(fill)
	var camera: Camera3D = Camera3D.new()
	studio.add_child(camera)
	camera.position = Vector3(0, 3.0, 12)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	camera.current = true
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	for index: int in ASSETS.size():
		var packed: PackedScene = load("res://scenes/characters/%s_visual.tscn" % ASSETS[index]) as PackedScene
		var actor: CartoonActor = packed.instantiate() as CartoonActor
		studio.add_child(actor)
		actor.position.x = (index - 2) * 2.1
		actor.rotation.y = deg_to_rad(-12)
		actors.append(actor)
		var meshes: Array[Node] = actor.find_children("*", "MeshInstance3D", true, false)
		var triangles: int = 0
		var materials_valid: bool = true
		for node: Node in meshes:
			var geometry: MeshInstance3D = node as MeshInstance3D
			for surface: int in geometry.mesh.get_surface_count():
				var arrays: Array = geometry.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size() / 3
				materials_valid = materials_valid and geometry.get_active_material(surface) != null
		_check(triangles > 1000 and triangles <= 5000, ASSETS[index] + " imported mesh budget: " + str(triangles))
		_check(materials_valid, ASSETS[index] + " material bindings")
		_check(actor.jelly or actor._parts.size() == 6, ASSETS[index] + " animation joints")
		var pedestal: MeshInstance3D = MeshInstance3D.new()
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.91
		cylinder.bottom_radius = 0.95
		cylinder.height = 0.12
		cylinder.radial_segments = 48
		pedestal.mesh = cylinder
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color("#48616e")
		pedestal.material_override = mat
		pedestal.position = Vector3(actor.position.x, -0.07, 0)
		studio.add_child(pedestal)
		var label: Label3D = Label3D.new()
		label.font = font
		label.text = LABELS[index]
		label.font_size = 44
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(actor.position.x, -0.40, 0.9)
		studio.add_child(label)
	await create_timer(0.4).timeout
	await _capture("cast-front")
	for actor: CartoonActor in actors: actor.rotation.y = deg_to_rad(100)
	await _capture("cast-side")
	for actor: CartoonActor in actors: actor.rotation.y = deg_to_rad(180)
	await _capture("cast-back")
	for actor: CartoonActor in actors:
		actor.rotation.y = deg_to_rad(-12)
		actor.set_motion(1.0)
	await create_timer(0.12).timeout
	_check(not actors[0]._parts[&"LegLeft"].transform.is_equal_approx(actors[0]._rest[&"LegLeft"]), "Walk animates the imported leg joint")
	await _capture("cast-walk")
	for actor: CartoonActor in actors: actor.set_dead(true)
	await create_timer(0.15).timeout
	_check(actors[0]._parts[&"LegLeft"].transform.is_equal_approx(actors[0]._rest[&"LegLeft"]), "Death resets pose and freezes animation")
	for actor: CartoonActor in actors:
		actor.set_dead(false)
		actor.set_motion(0.0)
	print("CARTOON_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	if "--manual" not in OS.get_cmdline_user_args():
		quit(0 if failures == 0 else 1)

func _capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/cartoon")
	var error: Error = root.get_texture().get_image().save_webp("res://artifacts/cartoon/" + file + ".webp", true, 0.85)
	_check(error == OK, "Rendered " + file)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])
