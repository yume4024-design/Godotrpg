extends SceneTree
## Native candidate controller check; does not replace scenes or touch RPG saves.
const ActorScript = preload("res://scripts/characters/female_actor.gd")
var checks: int = 0
var failures: Array[String] = []
var output: String
var actor: CartoonActor
var rig: Skeleton3D
var player: AnimationPlayer
var world: Node3D
var camera: Camera3D
var triangles: int = 0
var staff_triangles: int = 0

func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func step(seconds: float) -> void:
	for frame: int in range(ceili(seconds * 60)):
		actor.call("_process", 1.0 / 60)
		await process_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func attachment(label: String) -> void:
	await process_frame
	var staff: Node3D = actor.get("staff_visual")
	var hand: int = rig.find_bone("HandRight")
	var origin: Vector3 = actor.get("staff_rest_origin")
	var expected: Transform3D = rig.global_transform * rig.get_bone_global_pose(hand) * rig.get_bone_global_rest(hand).affine_inverse() * Transform3D(Basis.IDENTITY, origin)
	check(staff.global_position.distance_to(expected.origin) < .001, "staff socket follows hand " + label)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Pass candidate GLB and new output directory")
		quit(1)
		return
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	check(DisplayServer.get_name() != "headless", "native graphics required")
	root.size = Vector2i(720, 720)
	root.content_scale_size = root.size
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	check(doc.append_from_file(args[0], state) == OK, "raw GLB import")
	var raw: Node = doc.generate_scene(state)
	if raw == null:
		quit(1)
		return
	var packed := PackedScene.new()
	check(packed.pack(raw) == OK, "pack imported candidate")
	raw.free()
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("34434e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.3
	camera.position = Vector3(0, 1, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	actor = ActorScript.new()
	actor.model = packed
	actor.set("staff_rest_origin", Vector3(-.463, 1.015, -.061))
	actor.set("palm_rest_origin", Vector3(-.463, 1.015, -.061))
	actor.set("motion_profile", load(args[0].get_base_dir().path_join("lia_motion_profile.tres")))
	world.add_child(actor)
	actor.set_process(false)
	rig = actor.get("skeleton")
	player = actor.get("animation_player")
	check(rig != null and rig.get_bone_count() == 19, "nineteen imported bones")
	check(player != null, "existing animation controller initialized")
	for mesh: MeshInstance3D in (actor.get("_model_root") as Node).find_children("*", "MeshInstance3D", true, false):
		if (actor.get("staff_visual") as Node).is_ancestor_of(mesh):
			for surface: int in mesh.mesh.get_surface_count():
				staff_triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
			continue
		check(mesh.skin != null, "skin " + mesh.name)
		for surface: int in mesh.mesh.get_surface_count():
			triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
			check(mesh.get_active_material(surface) != null, "material " + mesh.name)
	check(triangles == 6474, "geometry count preserved")
	check(staff_triangles == 140, "existing rigid staff count")
	for clip: StringName in [&"walk", &"run", &"attack", &"cast", &"guard", &"hit", &"potion"]:
		check(player.has_animation(clip), "clip " + clip)
	await step(.3)
	await capture("rest_front")
	actor.call("set_equipment_visual", load("res://data/items/willow_staff.tres"))
	check((actor.get("staff_visual") as Node3D).visible, "staff equipped")
	for action: StringName in [&"attack", &"star_spark", &"guard", &"hit", &"potion"]:
		actor.call("play_battle_action", action)
		check(player.current_animation == (&"cast" if action == &"star_spark" else action), "action mapping " + action)
		await step(1.0 / 3)
		await attachment(action)
		await capture(String(action) + "_front")
		actor.rotation.y = PI / 2
		await capture(String(action) + "_side")
		actor.rotation.y = 0
		for bone: int in rig.get_bone_count():
			check(rig.get_bone_global_pose(bone).is_finite(), "finite " + action + " " + str(bone))
		await step(.6)
		check(actor.get("battle_pose") == &"" and not player.is_playing(), "action returns to idle " + action)
	for motion: float in [.4, 1.0, 0.0]:
		actor.set_motion(motion)
		actor.call("set_travel_speed", motion * 4.5)
		await step(.4)
		var expected: StringName = &"walk" if motion == .4 else &"run" if motion == 1 else &""
		check(player.current_animation == expected, "locomotion state " + expected)
		await attachment("locomotion")
		await capture("motion_" + str(motion))
		actor.rotation.y = PI / 2
		await capture("motion_side_" + str(motion))
		actor.rotation.y = 0
		if motion > 0:
			var minimum: float = INF
			var maximum: float = -INF
			for frame: int in 90:
				actor.call("_process", 1.0 / 60)
				var foot: Vector3 = rig.get_bone_global_pose(rig.find_bone("FootLeft")).origin
				minimum = minf(minimum, foot.z)
				maximum = maxf(maximum, foot.z)
			check(maximum - minimum > .2, "feet advance fore-aft " + expected)
	actor.set_motion(1)
	actor.call("play_battle_action", &"cast")
	await step(.9)
	check(player.current_animation == &"run", "battle action resumes running")
	actor.set_dead(true)
	await step(.2)
	check(not player.is_playing(), "death stops locomotion")
	actor.set_dead(false)
	actor.set_motion(0)
	await step(.4)
	check(not actor.get("_dead") and not player.is_playing(), "revival restores idle")
	actor.call("set_equipment_visual", null)
	check(not (actor.get("staff_visual") as Node3D).visible, "unequip staff")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "triangles": triangles, "staff_triangles": staff_triangles, "renderer": DisplayServer.get_name(), "model": args[0], "limits": ["Native automated controller review only", "Not gameplay/save regression, terrain IK or human acceptance"]}, "\t"))
	file.close()
	print("LIA_REBUILD_CONTROLLER_RESULT checks=%d failures=%d" % [checks, failures.size()])
	world.free()
	quit(0 if failures.is_empty() else 1)
