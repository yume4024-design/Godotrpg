extends SceneTree
## Two independent presentation instances; never changes dialogue/story/economy.

const NpcVisual = preload("res://scripts/characters/rigged_npc_visual.gd")
var model_scene: PackedScene
var asset_id: String = "blacksmith"
var output: String
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="): asset_id = argument.trim_prefix("--id=")
	if asset_id not in ["blacksmith", "item_merchant", "villager_male", "villager_female"]:
		push_error("Unknown NPC review asset")
		quit(1)
		return
	model_scene = load("res://scenes/characters/npc/" + asset_id + "_visual.tscn") as PackedScene
	output = "res://artifacts/asset_a05/" + asset_id + "/controller"
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _kind(player: AnimationPlayer) -> String:
	return String(player.current_animation).get_slice("|", String(player.current_animation).get_slice_count("|") - 1).get_file()

func _finite(skeleton: Skeleton3D) -> bool:
	for index: int in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_pose(index).is_finite(): return false
	return true

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
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
	light.rotation_degrees = Vector3(-40, -25, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(0, 1, 4)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1, 0))
	var actor_a: NpcVisual = model_scene.instantiate() as NpcVisual
	var actor_b: NpcVisual = model_scene.instantiate() as NpcVisual
	actor_a.position.x = -0.6
	actor_b.position.x = 0.6
	world.add_child(actor_a)
	world.add_child(actor_b)
	await process_frame
	var player_a: AnimationPlayer = actor_a.animation_player
	var player_b: AnimationPlayer = actor_b.animation_player
	_check(player_a != null and player_b != null, "two valid players")
	_check(actor_a.skeleton != actor_b.skeleton, "independent skeleton nodes")
	_check(player_a.get_animation_library("") != player_b.get_animation_library(""), "instance-local animation libraries")
	_check(_kind(player_a) == "idle" and _kind(player_b) == "idle", "both start idle")
	for cycle: int in range(3):
		actor_a.set_talking(true)
		actor_b.set_talking(false)
		await create_timer(0.22).timeout
		_check(_kind(player_a) == "talk" and _kind(player_b) == "idle", "independent talk/idle " + str(cycle))
		var position_before: float = player_a.current_animation_position
		actor_a.set_talking(true)
		await create_timer(0.05).timeout
		_check(player_a.current_animation_position > position_before, "repeated talk does not restart " + str(cycle))
		actor_a.set_talking(false)
		actor_b.set_talking(true)
		await create_timer(0.22).timeout
		_check(_kind(player_a) == "idle" and _kind(player_b) == "talk", "returns idle without changing peer " + str(cycle))
		_check(_finite(actor_a.skeleton) and _finite(actor_b.skeleton), "finite blended poses " + str(cycle))
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(output + "/idle_talk_pair.webp", true) == OK, "pair screenshot")
	actor_a.queue_free()
	await process_frame
	var reloaded: NpcVisual = model_scene.instantiate() as NpcVisual
	world.add_child(reloaded)
	await process_frame
	_check(_kind(reloaded.animation_player) == "idle", "reinstantiated actor starts idle")
	_check(_kind(player_b) == "talk", "peer survives reload")
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"asset": asset_id, "checks": checks, "failures": failures, "graphical": true,
		"model": actor_b.model.resource_path, "model_sha256": FileAccess.get_sha256(actor_b.model.resource_path),
		"formal_gameplay_test": false, "physical_input_test": false, "saves_written": false}, "\t"))
	print("NPC_VISUAL_TEST ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
