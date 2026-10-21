extends SceneTree
## Independent native GLTF inspection. Never installs a candidate or runs RPG state.
const MODEL: String = "res://source_assets/character_rebuild_20261020/ren/stitched_waist_20261021/ren_rigged.glb"
const OUTPUT: String = "res://artifacts/character_rebuild_20261020/ren/authored_godot"
const CLIPS: Array[String] = ["attack", "cast", "guard", "hit", "potion", "run", "walk"]
var model_path: String = MODEL
var output: String = OUTPUT
var checks: int = 0
var failures: Array[String] = []
var world: Node3D
var pivot: Node3D
var player: AnimationPlayer
var rig: Skeleton3D

func _initialize() -> void:
	Engine.max_fps = 60
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--model="):
			model_path = argument.trim_prefix("--model=")
	output = OUTPUT + "_" + model_path.get_base_dir().get_file()
	if not model_path.begins_with("res://source_assets/character_rebuild_20261020/ren/") or not model_path.ends_with(".glb"):
		push_error("Only an independent owned Ren work copy is supported")
		quit(1)
		return
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _kind(name: StringName) -> String:
	var text: String = String(name)
	return text.get_slice("|", text.get_slice_count("|")-1).get_file()

func _load_candidate() -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var result: Error = document.append_from_file(model_path, state)
	_check(result == OK, "Raw candidate GLTF parsed without copying into runtime assets")
	return document.generate_scene(state) as Node3D if result == OK else null

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	_check(image.save_webp(output+"/"+label+".webp", false, .88) == OK, "Native candidate capture " + label)

func _run() -> void:
	_check(DisplayServer.get_name() != "headless", "Graphical renderer required")
	root.size = Vector2i(720, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(output)
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
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.position = Vector3(0, .98, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, .98, 0))
	pivot = Node3D.new()
	world.add_child(pivot)
	var model: Node3D = _load_candidate()
	_check(model != null, "Candidate scene generated")
	if model == null: quit(1); return
	pivot.add_child(model)
	await process_frame
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var rigs: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	_check(players.size() == 1 and rigs.size() == 1, "Exactly one player and one skeleton")
	if players.size() != 1 or rigs.size() != 1: quit(1); return
	player = players[0] as AnimationPlayer
	rig = rigs[0] as Skeleton3D
	var expected_bones: Array[String] = ["Root", "Torso", "Head"]
	for side: String in ["Left", "Right"]:
		for name: String in ["Arm", "Forearm", "Hand", "Fingers", "Leg", "Shin", "Foot", "Coat"]:
			expected_bones.append(name+side)
	_check(rig.get_bone_count() == 19 and expected_bones.all(func(name: String) -> bool: return rig.find_bone(name) >= 0), "Nineteen original bone names retained")
	rig.reset_bone_poses()
	var rest_poses: Array[Transform3D] = []
	for bone: int in range(rig.get_bone_count()): rest_poses.append(rig.get_bone_pose(bone))
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 5, "Five independently skinned authored/retained meshes")
	var triangles: int = 0
	for node: MeshInstance3D in meshes:
		_check(node.skin != null, "Skin imported: " + node.name)
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
			_check(arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(), "UV imported: " + node.name)
			var material: StandardMaterial3D = node.get_active_material(surface) as StandardMaterial3D
			_check(material != null, "PBR material imported: " + node.name)
	_check(triangles == 10655 and triangles <= 15000, "10655 triangles within player_character budget")
	var names: Dictionary = {}
	for name: StringName in player.get_animation_list():
		if _kind(name) != "RESET": names[_kind(name)] = name
	_check(names.size() == 7 and CLIPS.all(func(name: String) -> bool: return names.has(name)), "Seven real authored clips; no invented Idle or missing clip substitute")
	for kind: String in CLIPS:
		if not names.has(kind): continue
		var animation: Animation = player.get_animation(names[kind])
		animation.loop_mode = Animation.LOOP_LINEAR if kind in ["walk", "run"] else Animation.LOOP_NONE
		player.play(names[kind], .0)
		for unused: int in range(12): await process_frame
		_check(player.current_animation_position > 0, "Native-clock playback advances: " + kind)
		player.pause()
		var finite: bool = true
		for fraction: float in [0., .25, .5, .75, .999]:
			player.seek(animation.length*fraction, true)
			await process_frame
			for bone: int in range(rig.get_bone_count()):
				var pose: Transform3D = rig.get_bone_pose(bone)
				finite = finite and pose.is_finite() and absf(pose.basis.determinant()) > .001
		_check(finite, "Representative skeleton transforms finite: " + kind)
		player.seek(animation.length*(.25 if kind in ["walk", "run"] else .5), true)
		pivot.rotation.y = 0
		await _capture(kind+"_front")
		pivot.rotation.y = PI/2
		await _capture(kind+"_side")
		pivot.rotation.y = 0
		if kind in ["walk", "run"]:
			player.seek(animation.length*.75, true)
			await _capture(kind+"_opposite_front")
			pivot.rotation.y = PI/2
			await _capture(kind+"_opposite_side")
			pivot.rotation.y = 0
		player.stop()
		rig.reset_bone_poses()
		await process_frame
		_check(range(rig.get_bone_count()).all(func(bone: int) -> bool: return rig.get_bone_pose(bone).is_equal_approx(rest_poses[bone])), "Stop/reset restores imported rest poses: " + kind)
	for view: int in range(4):
		pivot.rotation.y = view*PI/2
		await _capture("rest_"+str(view))
	model.free()
	model = _load_candidate()
	pivot.add_child(model)
	await process_frame
	_check(model.find_children("*", "Skeleton3D", true, false).size() == 1, "Fresh raw GLTF read regenerates skeleton")
	var report: Dictionary = {"model": model_path, "sha256": FileAccess.get_sha256(model_path), "checks": checks, "failures": failures,
		"triangles": triangles, "bones": 19, "clips": CLIPS, "graphical": true,
		"import_method": "Runtime GLTFDocument in isolated review; not production cached-resource import",
		"visual_acceptance": "HUMAN_REVIEW", "formal_gameplay": false, "physical_input": false}
	var file: FileAccess = FileAccess.open(output+"/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("REN_AUTHORED_REVIEW_RESULT checks=%d failures=%d triangles=%d" % [checks, failures.size(), triangles])
	quit(0 if failures.is_empty() else 1)
