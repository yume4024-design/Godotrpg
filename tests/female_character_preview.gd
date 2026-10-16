extends SceneTree
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(800,900)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	var rig: Skeleton3D = hero.get("skeleton")
	if rig == null or rig.get_bone_count() != 29: failures += 1
	hero.call("set_equipment_visual",load("res://data/items/willow_staff.tres"))
	var npcs: Node3D = load("res://scenes/world/greystone_npcs.tscn").instantiate()
	stage.add_child(npcs)
	var npc_visual: CartoonActor = npcs.get_node("Lia/Appearance")
	if npc_visual.model.resource_path != "res://assets/models/female/lia_rigged.glb": failures += 1
	npcs.queue_free()
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0,1,4)
	camera.look_at(Vector3(0,1,0))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-30,-30,0)
	for mesh: MeshInstance3D in hero.find_children("*","MeshInstance3D",true,false):
		print(mesh.name, " ", mesh.get_aabb(), " ", mesh.get_active_material(0))
	for pose: String in ["front","side","back","walk"]:
		hero.rotation.y = 0 if pose in ["front","walk"] else PI/2 if pose == "side" else PI
		hero.set_motion(1 if pose == "walk" else 0)
		await create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/female_character/godot_%s.webp" % pose)
	var leg: int = rig.find_bone("LegLeft")
	if rig.get_bone_pose_rotation(leg).is_equal_approx(rig.get_bone_rest(leg).basis.get_rotation_quaternion()): failures += 1
	hero.set_motion(0)
	var clips: AnimationPlayer = hero.get("animation_player")
	for clip: StringName in [&"attack", &"cast", &"guard", &"hit", &"potion"]:
		if not clips.has_animation(clip): failures += 1
	for action: StringName in [&"mend", &"hit"]:
		for view: String in ["front", "side", "back"]:
			hero.rotation.y = 0 if view == "front" else PI/2 if view == "side" else PI
			hero.call("play_battle_action", action)
			await create_timer(.3).timeout
			var joint: int = rig.find_bone("ForearmLeft" if action == &"mend" else "ShinLeft")
			if rig.get_bone_pose_rotation(joint).is_equal_approx(hero.get("rest_rotations")[joint]): failures += 1
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/female_character/rigged_%s_%s.webp" % [action,view])
			await create_timer(.45).timeout
			if not rig.get_bone_pose_rotation(joint).is_equal_approx(hero.get("rest_rotations")[joint]): failures += 1
	for amount: float in [.4,1.0]:
		var clip: String = "walk" if amount < .65 else "run"
		hero.set_motion(amount)
		await create_timer(.21).timeout
		if clips.current_animation != clip or clips.get_animation(clip).loop_mode != Animation.LOOP_LINEAR: failures += 1
		var animation: Animation = clips.get_animation(clip)
		for track: int in range(animation.get_track_count()):
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and animation.track_get_key_count(track)>1:
				var first: Quaternion = animation.track_get_key_value(track,0)
				var last: Quaternion = animation.track_get_key_value(track,animation.track_get_key_count(track)-1)
				if first.angle_to(last) > .001: failures += 1
		for view: String in ["front","side","back"]:
			hero.rotation.y = 0 if view == "front" else PI/2 if view == "side" else PI
			clips.seek(.21,true)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/female_character/%s_%s.webp" % [clip,view])
		await create_timer(1.1).timeout
		if not clips.is_playing() or hero.position != Vector3.ZERO: failures += 1
		hero.call("play_battle_action",&"mend")
		if hero.get("battle_pose") != &"mend": failures += 1
		await create_timer(.8).timeout
		if clips.current_animation != clip or hero.get("battle_pose") != &"": failures += 1
	hero.set_motion(0)
	await create_timer(.2).timeout
	if clips.is_playing(): failures += 1
	for name: String in ["ForearmLeft","ShinLeft","CoatLeft","CoatRight"]:
		var joint: int = rig.find_bone(name)
		if not rig.get_bone_pose_rotation(joint).is_equal_approx(hero.get("rest_rotations")[joint]): failures += 1
	var root_joint: int = rig.find_bone("Root")
	if not rig.get_bone_pose_position(root_joint).is_equal_approx(hero.get("_clip_positions")[root_joint]): failures += 1
	hero.set_motion(.7)
	await create_timer(.16).timeout
	if clips.current_animation != &"walk": failures += 1
	hero.set_motion(.75)
	await create_timer(.16).timeout
	hero.set_motion(.66)
	await create_timer(.16).timeout
	if clips.current_animation != &"run": failures += 1
	hero.call("play_battle_action",&"mend")
	await create_timer(.8).timeout
	if clips.current_animation != &"run": failures += 1
	clips.seek(.16,true)
	var before_stop: Quaternion = rig.get_bone_pose_rotation(leg)
	hero.set_motion(0)
	for frame: int in range(10):
		await process_frame
		var current: Quaternion = rig.get_bone_pose_rotation(leg)
		if before_stop.angle_to(current)>.1: failures += 1
		before_stop = current
	await create_timer(.2).timeout
	if clips.is_playing(): failures += 1
	hero.set_dead(true)
	await create_timer(.1).timeout
	print("FEMALE_PREVIEW_COMPLETE failures=%d" % failures)
	stage.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
