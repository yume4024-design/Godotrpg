extends SceneTree
## Independent visual-controller integration; no RPG state, save or reward owner is instantiated.
var asset: String = "spore_sprite"
var expected_bones: int = 7
var scene: PackedScene
var output: String
var secondary_action: StringName
var secondary_clip: String
var motion_clip: String
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--asset="): asset = argument.trim_prefix("--asset=")
	if asset not in ["spore_sprite", "ore_beetle", "thorn_boar", "corrupted_guardian"]:
		push_error("Unsupported integrated enemy: " + asset)
		quit(1)
		return
	expected_bones = {"spore_sprite":7,"ore_beetle":15,"thorn_boar":12,"corrupted_guardian":17}[asset]
	secondary_action = {"spore_sprite":&"rupture","ore_beetle":&"attack","thorn_boar":&"charge","corrupted_guardian":&"rupture"}[asset]
	secondary_clip = {"spore_sprite":"cast","ore_beetle":"attack","thorn_boar":"charge","corrupted_guardian":"cast"}[asset]
	motion_clip = "run" if asset=="thorn_boar" else "walk"
	scene = load("res://scenes/characters/rebuilt/%s_visual.tscn" % asset)
	output = "res://artifacts/a04_%s_controller/" % asset
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _kind(actor: RiggedEnemyActor) -> String:
	var clip: String = String(actor.animation_player.assigned_animation)
	return clip.get_slice("|",clip.get_slice_count("|")-1).get_file().to_lower()

func _finite(actor: RiggedEnemyActor) -> bool:
	for bone: int in range(actor.skeleton.get_bone_count()):
		if not actor.skeleton.get_bone_pose(bone).is_finite(): return false
	return true

func _poses(actor: RiggedEnemyActor) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone: int in range(actor.skeleton.get_bone_count()): poses.append(actor.skeleton.get_bone_pose(bone))
	return poses

func _changed(actor: RiggedEnemyActor, poses: Array[Transform3D]) -> bool:
	for bone: int in range(actor.skeleton.get_bone_count()):
		if not actor.skeleton.get_bone_pose(bone).is_equal_approx(poses[bone]): return true
	return false

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(output+label+".webp") == OK,"Actual controller frame " + label)

func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1100,700)
	DirAccess.make_dir_recursive_absolute(output)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("34434e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = .75
	world.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	world.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0 if asset=="corrupted_guardian" else (5.0 if asset!="spore_sprite" else 3.6)
	camera.position = Vector3(0,1.3,4)
	world.add_child(camera)
	camera.look_at(Vector3(0,.7,0))
	var first: RiggedEnemyActor = scene.instantiate() as RiggedEnemyActor
	var second: RiggedEnemyActor = scene.instantiate() as RiggedEnemyActor
	first.position.x = -1.5 if asset!="spore_sprite" else -1.1
	second.position.x = 1.5 if asset!="spore_sprite" else 1.1
	world.add_child(first)
	world.add_child(second)
	await process_frame
	_check(first.animation_player != null and second.animation_player != null,"Two real animation players")
	_check(first.skeleton != second.skeleton and first.skeleton.get_bone_count()==expected_bones,"Independent imported rigs")
	_check(first.animation_player.get_animation_library("") != second.animation_player.get_animation_library(""),"Instance-owned loop metadata")
	_check(_kind(first)=="idle" and _kind(second)=="idle","Both begin with real idle")
	_check(not first.procedural_fall and first.nameplate_anchor != null,"Authored death and nameplate presentation")
	_check(not first.play_battle_action(&"unknown") and _kind(first)=="idle","Unknown actions cannot invent a clip")
	first.set_motion(.35)
	await create_timer(.2).timeout
	_check(_kind(first)=="walk", "Low motion uses real walk for each imported enemy")
	for cycle: int in range(3):
		first.set_motion(1.0)
		await create_timer(.15).timeout
		_check(_kind(first)==motion_clip and _kind(second)=="idle","Locomotion isolated from peer " + str(cycle))
		if cycle==0: await _capture("locomotion-"+motion_clip)
		var before_attack: Array[Transform3D] = _poses(first)
		_check(first.play_battle_action(&"attack"),"Attack uses imported clip")
		first.set_motion(0.0)
		await create_timer(.15).timeout
		_check(_kind(first)=="attack","Locomotion request cannot interrupt attack")
		_check(_changed(first,before_attack),"Imported attack changes real bone poses")
		await _capture("attack-"+str(cycle))
		await create_timer(1.2).timeout
		_check(_kind(first)=="idle" and first.animation_player.is_playing(),"Real-clock attack finishes into requested idle")
		var before_cast: Array[Transform3D] = _poses(first)
		_check(first.play_battle_action(secondary_action),"Existing action maps to authored clip")
		await create_timer(.3).timeout
		_check(_kind(first)==secondary_clip,"Secondary authored action is playing")
		_check(_changed(first,before_cast),"Secondary action changes real bone poses")
		if cycle==0: await _capture("secondary-"+secondary_clip)
		_check(first.play_battle_action(&"hit"),"Hit can interrupt action")
		await create_timer(.2).timeout
		_check(first.play_battle_action(&"hit"),"Second impact accepted")
		_check(first.animation_player.current_animation_position < .03,"Repeated impact starts at beginning")
		await create_timer(.9).timeout
		_check(_kind(first)=="idle","Hit returns idle")
		first.set_dead(true)
		await create_timer(.25).timeout
		var before: float = first.animation_player.current_animation_position
		first.set_dead(true)
		await create_timer(.1).timeout
		_check(_kind(first)=="death" and first.animation_player.current_animation_position>before,"Refresh does not restart death")
		_check(not first.play_battle_action(&"attack"),"Death blocks subsequent battle actions")
		await create_timer(1.3).timeout
		_check(not first.animation_player.is_playing() and _finite(first),"Death holds a finite final pose")
		if cycle==0: await _capture("death")
		first.set_dead(false)
		await create_timer(.18).timeout
		_check(_kind(first)=="idle" and _finite(first) and _kind(second)=="idle","Retry/reset restores visual without peer mutation")
	if asset=="corrupted_guardian":
		for action: StringName in [&"heavy_attack", &"special_attack", &"stagger"]:
			var before_extra: Array[Transform3D] = _poses(first)
			_check(first.play_battle_action(action), "Existing auxiliary clip is playable " + str(action))
			await create_timer(.3).timeout
			_check(_kind(first)==str(action) and _changed(first,before_extra), "Auxiliary clip changes actual poses " + str(action))
			await _capture(str(action))
			await create_timer(2.1).timeout
			_check(_kind(first)=="idle" and _finite(first), "Auxiliary clip returns idle " + str(action))
	await _capture("reset-pair")
	first.queue_free()
	await process_frame
	var replacement: RiggedEnemyActor = scene.instantiate() as RiggedEnemyActor
	world.add_child(replacement)
	await process_frame
	_check(_kind(replacement)=="idle" and _kind(second)=="idle","Reload frees prior actor and retains peer")
	var report: Dictionary = {"checks":checks,"failures":failures,"graphical":DisplayServer.get_name()!="headless","asset":asset,"bones":expected_bones,"model_sha256":FileAccess.get_sha256(second.model.resource_path),"formal_battle":false,"method":"Real-clock two-instance clip switching, hit interruption, death freeze, revival and scene reload; rendered frames reviewed separately."}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ENEMY_CONTROLLER_RESULT checks=%d failures=%d" % [checks,failures.size()])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
