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
	if rig == null or rig.get_bone_count() != 11: failures += 1
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
	hero.set_dead(true)
	await create_timer(.1).timeout
	print("FEMALE_PREVIEW_COMPLETE failures=%d" % failures)
	stage.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
