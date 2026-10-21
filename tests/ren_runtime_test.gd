extends SceneTree
## Real renderer + existing actor controller; RPG state is exercised separately.
const OUTPUT: String = "res://artifacts/ren_runtime/controller"
const SCENE: PackedScene = preload("res://scenes/characters/ren_rebuilt_visual.tscn")
const CLIPS: Array[StringName] = [&"attack", &"cast", &"guard", &"hit", &"potion", &"walk", &"run", &"idle", &"sword_idle", &"sword_attack", &"sword_guard", &"death", &"walk_narrow", &"run_narrow"]
var checks: int = 0
var failures: Array[String] = []
var actor: CartoonActor
var rig: Skeleton3D
var clips: AnimationPlayer
var equipment: HandEquipmentVisual
var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _step(seconds: float) -> void:
	for index: int in range(ceili(seconds * 60)):
		actor.call("_process", 1.0 / 60.0)
		await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	_check(image.save_webp(OUTPUT + "/" + label + ".webp", false, .88) == OK, "Native capture " + label)

func _attachment(label: String) -> void:
	await process_frame
	var hand: int = rig.find_bone("HandRight")
	var basis: Basis = Basis(Quaternion(Vector3.UP, equipment.blade_direction.normalized()))
	var expected: Transform3D = rig.global_transform * rig.get_bone_global_pose(hand) * rig.get_bone_global_rest(hand).affine_inverse() * Transform3D(basis, equipment.rest_origin)
	_check(equipment.visual.global_position.distance_to(expected.origin) < .0001, label + " grip follows the animated hand")
	_check(equipment.visual.global_basis.y.normalized().dot(expected.basis.y.normalized()) > .9999, label + " blade orientation follows hand")

func _run() -> void:
	_check(DisplayServer.get_name() != "headless", "Native graphical renderer required")
	root.size = Vector2i(720, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("34434e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	world.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.position = Vector3(0, .98, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, .98, 0))
	actor = SCENE.instantiate()
	world.add_child(actor)
	actor.set_process(false)
	rig = actor.get("skeleton") as Skeleton3D
	clips = actor.get("animation_player") as AnimationPlayer
	equipment = actor.get("equipment_visual") as HandEquipmentVisual
	_check(rig.get_bone_count() == 19, "Nineteen validated bones")
	_check(actor.get("staff_visual") == null, "Sword actor does not instantiate a hidden staff")
	_check(not actor.procedural_fall, "Authored death does not receive a second BattleStage fall")
	for clip: StringName in CLIPS: _check(clips.has_animation(clip), "Imported animation " + clip)
	var body_triangles: int = 0
	var weapon_triangles: int = 0
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var count: int = 0
		for surface: int in range(mesh.mesh.get_surface_count()):
			count += mesh.mesh.surface_get_array_index_len(surface) / 3
			_check(mesh.get_active_material(surface) != null, "Material " + mesh.name)
		if equipment.visual.is_ancestor_of(mesh): weapon_triangles += count
		else: body_triangles += count
	_check(body_triangles == 10655 and body_triangles <= 15000, "Actual imported body budget")
	_check(weapon_triangles == 330 and weapon_triangles <= 1000, "Actual separate weapon budget")
	await _step(.25)
	_check(clips.current_animation == &"idle", "Unarmed authored idle")
	_check(not equipment.visual.visible, "No equipment means no sword")
	actor.call("set_equipment_visual", load("res://data/items/bronze_sword.tres"))
	await _step(.25)
	_check(clips.current_animation == &"sword_idle" and equipment.visual.visible, "Equipped authored idle")
	await _attachment("idle")
	for view: String in ["front", "right", "back"]:
		actor.rotation.y = 0 if view == "front" else PI / 2 if view == "right" else PI
		await process_frame
		await _capture("sword_idle_" + view)
	actor.rotation.y = 0
	for action: StringName in [&"attack", &"guard", &"star_spark", &"hit", &"potion"]:
		actor.play_battle_action(action)
		var expected: StringName = &"sword_attack" if action == &"attack" else &"sword_guard" if action == &"guard" else &"cast" if action == &"star_spark" else action
		_check(clips.current_animation == expected, "Action mapping " + action)
		await _step(.2)
		await _attachment(String(action))
		await _capture(String(action) + "_front")
		actor.rotation.y = PI / 2
		await process_frame
		await _capture(String(action) + "_right")
		actor.rotation.y = 0
		await _step(.8)
		_check(actor.get("battle_pose") == &"" and clips.current_animation == &"sword_idle", "Action returns to authored idle " + action)
	for speed: float in [1.8, 4.5, 0.0]:
		actor.call("set_travel_speed", speed)
		actor.set_motion(speed / 4.5)
		await _step(.3)
		var expected: StringName = &"sword_idle" if speed == 0 else &"walk_narrow" if speed < 3 else &"run_narrow"
		_check(clips.current_animation == expected, "Motion state " + expected)
		if speed > 0:
			var minimum: float = INF
			var maximum: float = -INF
			for frame: int in range(90):
				actor.call("_process", 1.0 / 60.0)
				var foot: Vector3 = rig.get_bone_global_pose(rig.find_bone("FootLeft")).origin
				minimum = minf(minimum, foot.z)
				maximum = maxf(maximum, foot.z)
			_check(maximum - minimum > (.3 if speed < 3 else .6), "Actual fore-aft foot stride " + expected)
		await _attachment(String(expected))
		await _capture(String(expected))
	var finger: int = rig.find_bone("FingersRight")
	var rotation: Quaternion = rig.get_bone_pose_rotation(finger)
	for index: int in range(20): equipment.apply_grip()
	_check(absf(rotation.dot(rig.get_bone_pose_rotation(finger))) > .999999, "Grip does not accumulate")
	actor.set_dead(true)
	await _step(.4)
	var elapsed: float = clips.current_animation_position
	actor.set_dead(true)
	_check(is_equal_approx(elapsed, clips.current_animation_position), "Repeated battle refresh does not restart death")
	await _step(.8)
	_check(not clips.is_playing() and actor.get("_dead"), "Death completes and holds")
	var root_bone: int = rig.find_bone("Root")
	var fallen: Transform3D = rig.get_bone_pose(root_bone)
	await _step(.3)
	_check(rig.get_bone_pose(root_bone).is_equal_approx(fallen), "Dead pose remains stable")
	await _capture("death")
	actor.set_dead(false)
	await _step(.3)
	_check(clips.current_animation == &"sword_idle" and not actor.get("_dead"), "Revive restores authored idle")
	actor.call("set_equipment_visual", null)
	await _step(.3)
	_check(not equipment.visual.visible and clips.current_animation == &"idle", "Unequip restores unarmed presentation")
	actor.play_battle_action(&"attack")
	_check(clips.current_animation == &"attack", "Unarmed attack keeps original clip")
	await _step(.8)
	var other: CartoonActor = SCENE.instantiate()
	world.add_child(other)
	other.position.x = 4
	other.set_process(false)
	other.call("set_equipment_visual", load("res://data/items/bronze_sword.tres"))
	other.play_battle_action(&"guard")
	_check(clips.current_animation == &"idle", "Second instance does not change first animation")
	_check((other.get("equipment_visual") as HandEquipmentVisual).visual != equipment.visual, "Equipment is per instance")
	_check(other.get("animation_player") != clips, "Animation player is per instance")
	other.free()
	var report: Dictionary = {"checks": checks, "failures": failures, "renderer": DisplayServer.get_name(), "body_triangles": body_triangles, "weapon_triangles": weapon_triangles, "clips": CLIPS, "limits": ["Native automated controller test; not human input acceptance", "No independent fingers, terrain IK or formal model promotion"]}
	var file: FileAccess = FileAccess.open(OUTPUT + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("REN_RUNTIME_RESULT: checks=%d failures=%d" % [checks, failures.size()])
	world.free()
	quit(0 if failures.is_empty() else 1)
