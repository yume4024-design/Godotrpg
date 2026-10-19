extends SceneTree
## Graphical import/motion review only; no gameplay services or real save writes.

const Budget = preload("res://scripts/tools/asset_budget_policy.gd")
var world: Node3D
var pivot: Node3D
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var checks: int = 0
var failures: Array[String] = []
var model_path: String = "res://assets/models/rebuilt_enemies/spore_sprite.glb"
var asset_id: String = "spore_sprite"
var category: String = "common_enemy"
var height: float = 1.2
var output: String
var clips: Array[Dictionary] = []
var triangles: int = 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--model="): model_path = argument.trim_prefix("--model=")
		if argument.begins_with("--id="): asset_id = argument.trim_prefix("--id=")
		if argument.begins_with("--category="): category = argument.trim_prefix("--category=")
		if argument.begins_with("--height="): height = argument.trim_prefix("--height=").to_float()
	output = "res://artifacts/asset_a03/" + asset_id + "/godot"
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _kind(clip: StringName) -> String:
	return String(clip).get_slice("|", String(clip).get_slice_count("|") - 1).get_file()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	_check(picture.save_webp(output + "/" + label + ".webp", true, 0.92) == OK, label + " captured")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = Node3D.new()
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
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.0
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height * 1.7
	camera.position = Vector3(0, height * 0.52, height * 3)
	world.add_child(camera)
	camera.look_at(Vector3(0, height * 0.52, 0))
	pivot = Node3D.new()
	world.add_child(pivot)
	var packed := load(model_path) as PackedScene
	_check(packed != null, "GLB imported")
	if packed == null:
		quit(1)
		return
	model = packed.instantiate() as Node3D
	pivot.add_child(model)
	await process_frame
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	_check(players.size() == 1 and skeletons.size() == 1, "single animation player and skeleton")
	if players.size() != 1 or skeletons.size() != 1:
		quit(1)
		return
	player = players[0] as AnimationPlayer
	skeleton = skeletons[0] as Skeleton3D
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		_check(instance.skin != null, "mesh has skin")
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			_check(arrays[Mesh.ARRAY_TEX_UV] != null and not (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty(), "UV present")
			var material := instance.get_active_material(surface) as StandardMaterial3D
			_check(material != null and material.albedo_texture != null, "embedded albedo imported")
	_check(Budget.within_budget(triangles, category), "classified triangle budget")
	var kinds: Array[String] = []
	for clip: StringName in player.get_animation_list():
		if _kind(clip) == "RESET": continue
		kinds.append(_kind(clip))
		var animation := player.get_animation(clip)
		var looped: bool = _kind(clip) in ["idle", "walk", "run"]
		animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		_check(animation.length > 0.1, _kind(clip) + " duration")
		player.play(clip, 0.0)
		player.advance(0.0)
		player.pause()
		var first: Array[Transform3D] = []
		var motion: bool = false
		for fraction: float in [0.0, 0.25, 0.5, 0.75, 0.999]:
			player.seek(animation.length * fraction, true)
			await process_frame
			for bone: int in range(skeleton.get_bone_count()):
				var pose: Transform3D = skeleton.get_bone_pose(bone)
				_check(pose.is_finite() and absf(pose.basis.determinant()) > 0.001, _kind(clip) + " finite pose")
				if fraction == 0.0: first.append(pose)
				else: motion = motion or not pose.is_equal_approx(first[bone])
		_check(motion, _kind(clip) + " changes pose")
		var representative: float = 0.999 if _kind(clip) == "death" else 0.25 if _kind(clip) in ["idle", "walk", "run"] else 0.43 if _kind(clip) == "charge" else 0.5
		player.seek(animation.length * representative, true)
		await _capture(_kind(clip))
		pivot.rotation.y = PI / 2.0
		await _capture(_kind(clip) + "_side")
		pivot.rotation.y = 0
		player.play(clip, 0.0)
		player.advance(0.0)
		player.advance(animation.length * 2.0 + 0.1)
		_check(player.is_playing() == looped, _kind(clip) + " loop/one-shot playback")
		skeleton.reset_bone_poses()
		clips.append({"name": _kind(clip), "length": animation.length})
	for required: String in ["idle", "walk", "attack", "hit", "death"]:
		_check(required in kinds, "required " + required)
	var idle: StringName = &""
	for clip: StringName in player.get_animation_list():
		if _kind(clip) == "idle": idle = clip
	player.play(idle, 0.0)
	player.advance(0.0)
	player.pause()
	for view: int in range(4):
		pivot.rotation.y = view * PI / 2.0
		await _capture("view_" + str(view))
	model.free()
	model = packed.instantiate() as Node3D
	pivot.add_child(model)
	await process_frame
	_check(model.find_children("*", "Skeleton3D", true, false).size() == 1, "instantiate again retains rig")
	var report: Dictionary = {"asset": asset_id, "model": model_path, "model_sha256": FileAccess.get_sha256(model_path), "checks": checks, "failures": failures,
		"triangles": triangles, "category": category, "clips": clips, "graphical": true,
		"physical_input_test": false, "formal_battle_test": false,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"engine_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ASSET_MOTION_REVIEW ", asset_id, " ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
