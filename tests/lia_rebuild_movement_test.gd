extends "res://tests/lia_rebuild_story_test.gd"
## Real latest village, InputMap and collision. Model swap is confined to this fixture.
const SoleProbe = preload("res://tests/female_slope_test.gd")
var movement_rows: Array[Dictionary] = []
var misses: int = 0
var pose_samples: int = 0
var sole_minimum: float = INF
var stance_maximum: float = -INF
var pose_finite: bool = true
var body_mesh: MeshInstance3D
var actor_rig: Skeleton3D
var placement: LiaFootPlacement
var worst_stance: Dictionary = {}
var worst_penetration: Dictionary = {}
var missed_points: Array[Dictionary] = []

func _create_game() -> ExplorationGame:
	var instance: ExplorationGame = super._create_game()
	instance.set("hero_appearance", candidate)
	return instance

func _physical_distance(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .6, point - Vector3.UP * 1.0, game.player.collision_mask)
	query.exclude = [game.player.get_rid()]
	var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		misses += 1
		var nearby: Array[Dictionary] = []
		for dz: float in [-.01, -.001, .001, .01]:
			query.from.z = point.z + dz
			query.to.z = point.z + dz
			var neighbor: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
			nearby.append({"dz":dz,"hit":str(neighbor.get("position", "missing")),"collider":str(neighbor.get("collider", "missing"))})
		missed_points.append({"point":str(point),"player":str(game.player.position),"sample":pose_samples,"nearby":nearby})
		return INF
	return point.y - (hit.position as Vector3).y

func _observe() -> void:
	var soles: Dictionary = SoleProbe._soles(body_mesh, actor_rig, Vector3.UP, _physical_distance)
	var value: float = minf(soles.Left, soles.Right)
	var snapshot: Dictionary = {"distance":value,"player":str(game.player.position),"left":soles.Left,"right":soles.Right,"sample":pose_samples}
	if value > stance_maximum: worst_stance = snapshot
	if value < sole_minimum: worst_penetration = snapshot
	sole_minimum = minf(sole_minimum, value)
	stance_maximum = maxf(stance_maximum, minf(soles.Left, soles.Right))
	for bone: int in actor_rig.get_bone_count():
		pose_finite = pose_finite and actor_rig.get_bone_global_pose(bone).is_finite()
	pose_samples += 1

func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"move_run"]:
		Input.action_release(action)

func _direction(world: Vector3, running: bool) -> void:
	_release()
	var right: Vector3 = game.camera.global_basis.x
	var back: Vector3 = game.camera.global_basis.z
	right.y = 0
	back.y = 0
	var direction: Vector2 = Vector2(world.dot(right.normalized()), world.dot(back.normalized()))
	Input.action_press(&"move_right" if direction.x > 0 else &"move_left", absf(direction.x))
	Input.action_press(&"move_back" if direction.y > 0 else &"move_forward", absf(direction.y))
	if running: Input.action_press(&"move_run")
	game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)

func _walk(target: Vector3, running: bool) -> bool:
	var count: int = 0
	var grounded: int = 0
	var best: float = INF
	var stalled: int = 0
	for frame: int in 1500:
		var difference: Vector3 = target - game.player.position
		difference.y = 0
		if difference.length() < .25: break
		if difference.length() < best - .01:
			best = difference.length()
			stalled = 0
		else: stalled += 1
		if stalled > 90: break
		_direction(difference.normalized(), running)
		await physics_frame
		count += 1
		if game.player.is_on_floor(): grounded += 1
		if frame % 6 == 0: _observe()
	_release()
	for settle: int in 18: await physics_frame
	_observe()
	if target.is_equal_approx(Vector3(-7,1.5,26)):
		var original_size: float = game.camera.size
		game.camera.size = 5.0
		await _capture("stairs_stop_" + str(movement_rows.size()))
		game.camera.size = original_size
	var reached: bool = Vector2(target.x, target.z).distance_to(Vector2(game.player.position.x, game.player.position.z)) < .3 and absf(game.player.position.y - target.y) < .6
	_check(count > 0 and grounded >= count * .95, "Capsule remains grounded during real route")
	_check(game.player.velocity.length() < .01, "Released input stops the player")
	_check(not (game.player.appearance.get("animation_player") as AnimationPlayer).is_playing(), "Stop restores locomotion idle")
	movement_rows.append({"target":str(target),"end":str(game.player.position),"run":running,"frames":count,"grounded":grounded,"reached":reached})
	return reached

func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.unfocusable = true
	game = _create_game()
	(game.get_node("Saves") as SaveManager).slot_path = "user://lia_rebuild_story/movement.json"
	_attach_game(game)
	# This fixture drives InputMap directly; disable the story test's keyboard reassertion.
	physics_frame.disconnect(_maintain_keyboard)
	await create_timer(1).timeout
	await _finish_dialogue()
	_check(DisplayServer.get_name() != "headless", "Native graphics required")
	_check(game.travel.current_map.get_node("Village").scene_file_path == "res://scenes/world/greystone_reference_master.tscn", "Latest village is actually loaded")
	_check(game.player.appearance.model != null, "Candidate is actual moving player visual")
	actor_rig = game.player.appearance.get("skeleton")
	body_mesh = game.player.appearance.find_child("LiaRetainedAuthoredNeckSurface", true, false) as MeshInstance3D
	_check(body_mesh != null and body_mesh.skin != null, "Imported body available for physical sole measurements")
	if body_mesh == null:
		game.free()
		quit(1)
		return
	if "--foot-placement" in OS.get_cmdline_user_args():
		placement = LiaFootPlacement.new()
		placement.skeleton = actor_rig
		placement.actor = game.player.appearance
		placement.body = game.player
		placement.sole_height = .18
		placement.sole_front = .185
		placement.sole_back = .11
		placement.sole_half_width = .10
		placement.normalize_stance_lift = true
		placement.allow_motion = true
		placement.physics_pose = true
		game.player.appearance.call("set_animation_physics", true)
		game.player.appearance.add_child(placement)
	var routes: Dictionary = {
		"inn_walk": [Vector3(-3,3.4,3),Vector3(-5,3,-7),Vector3(-9,3,-9.8),Vector3(-5,3,-7),Vector3(-3,3,3)],
		"entry_steps_run": [Vector3(-7,.4,35),Vector3(-7,0,29),Vector3(-7,1.5,26),Vector3(-7,3,23),Vector3(-7,1.5,26),Vector3(-7,0,29)],
		"mine_steps_run": [Vector3(-19,3.4,-19),Vector3(-24,6,-25),Vector3(-25,6,-29),Vector3(-10,6,-29),Vector3(8,6,-29),Vector3(3,6,-36),Vector3(0,10,-43)],
		"bridge_and_steps": [Vector3(14,3.4,-3),Vector3(19,3.08,-6),Vector3(27,3.7,-6),Vector3(35,3.08,-6),Vector3(39,3,-6),Vector3(40,3,-10),Vector3(40,6,-17)]}
	for name: String in routes:
		var points: Array = routes[name]
		game.player.reset_to(points[0])
		for settle: int in 25: await physics_frame
		for target: Vector3 in points.slice(1):
			var reached: bool = await _walk(target, name != "inn_walk")
			_check(reached, "Actual village " + name + " reaches " + str(target))
			if not reached: break
		await _capture(name)
	_check(pose_finite and pose_samples > 120, "Sustained walk/run/turn/stop has finite bones")
	_check(misses == 0, "Sampled sole vertices have supporting collision")
	_check(sole_minimum > -.05, "Soles avoid more than 5cm physical penetration")
	_check(stance_maximum < .08, "One stance foot stays within 8cm of terrain")
	var result: Dictionary = {"checks":checks,"failures":failures,"routes":movement_rows,"worst_stance":worst_stance,"worst_penetration":worst_penetration,"missed_points":missed_points,"pose_samples":pose_samples,"ray_misses":misses,"minimum_sole_m":sole_minimum,"maximum_stance_m":stance_maximum,"renderer":DisplayServer.get_name(),"foot_placement":is_instance_valid(placement),"limits":["Automated InputMap movement, not human Xbox acceptance","Foot placement opt-in flag is recorded; not production enablement"]}
	FileAccess.open(output_dir.path_join("movement.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LIA_CANDIDATE_MOVEMENT ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
