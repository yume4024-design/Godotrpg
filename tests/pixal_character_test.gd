extends SceneTree
const BUDGET_POLICY = preload("res://scripts/tools/asset_budget_policy.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(900,900)
	Engine.max_fps = 60
	for character: String in ["ren","lia"]:
		var stage: Node3D = Node3D.new()
		root.add_child(stage)
		var actor: CartoonActor = load("res://scenes/characters/%s_pixal_visual.tscn" % character).instantiate()
		stage.add_child(actor)
		var rig: Skeleton3D = actor.get("skeleton")
		var clips: AnimationPlayer = actor.get("animation_player")
		var camera: Camera3D = Camera3D.new()
		stage.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.35
		camera.position = Vector3(0,1,3)
		camera.look_at(Vector3(0,1,0))
		var environment: WorldEnvironment = WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("#637b86")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = .6
		stage.add_child(environment)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-25,-25,0)
		light.light_energy = .45
		light.shadow_enabled = true
		stage.add_child(light)
		await create_timer(.2).timeout
		var triangles: int = 0
		var textured: int = 0
		for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree(): continue
			for surface: int in range(mesh.mesh.get_surface_count()):
				triangles += mesh.mesh.surface_get_array_index_len(surface)/3
				var material: StandardMaterial3D = mesh.get_active_material(surface)
				_check(material!=null,character+" material imported")
				if material.albedo_texture!=null: textured += 1
		_check(BUDGET_POLICY.within_budget(triangles,"player_character"),character+" actual Godot mesh budget")
		_check(textured>0,character+" generated UV texture preserved")
		_check(rig.get_bone_count()==19,character+" fresh humanoid rig imports")
		_check((actor.get("_blink_meshes") as Array).size()==8,character+" eight new eyelid morph surfaces")
		for clip: StringName in [&"attack",&"cast",&"guard",&"hit",&"potion",&"walk",&"run"]:
			_check(clips.has_animation(clip),character+" imported clip "+clip)
		for view: String in ["front","right","back"]:
			actor.rotation.y = 0 if view=="front" else (PI/2 if view=="right" else PI)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/pixal3d/%s/godot_%s.webp" % [character,view])
		actor.rotation.y = 0
		actor.set_motion(.4)
		await create_timer(.3).timeout
		_check(clips.current_animation==&"walk",character+" walking cycle starts")
		actor.set_motion(1)
		await create_timer(.3).timeout
		_check(clips.current_animation==&"run",character+" running cycle starts")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/pixal3d/%s/godot_run.webp" % character)
		actor.set_motion(0)
		await create_timer(.3).timeout
		_check(not clips.is_playing(),character+" stops and restores locomotion")
		if character=="lia": actor.call("set_equipment_visual",load("res://data/items/willow_staff.tres"))
		for action: StringName in [&"attack",&"mend",&"guard",&"potion",&"hit"]:
			actor.call("play_battle_action",action)
			await create_timer(.28).timeout
			_check(actor.get("battle_pose")==action,character+" action active "+action)
			var finite: bool = true
			for bone: int in range(rig.get_bone_count()): finite = finite and rig.get_bone_global_pose(bone).is_finite()
			_check(finite,character+" finite deformed skeleton "+action)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/pixal3d/%s/godot_%s.webp" % [character,action])
			await create_timer(.5).timeout
			_check(actor.get("battle_pose")==&"",character+" action recovers "+action)
		if character=="lia":
			_check((actor.get("staff_visual") as Node3D).visible,"New Lia holds existing equipped staff")
			actor.call("set_equipment_visual",null)
			_check(not (actor.get("staff_visual") as Node3D).visible,"New Lia unequips staff")
		actor.set_dead(true)
		_check(actor.get("battle_pose")==&"",character+" death clears action")
		var closed: bool = true
		for mesh: MeshInstance3D in actor.get("_blink_meshes"):
			closed = closed and is_equal_approx(mesh.get_blend_shape_value(mesh.find_blend_shape_by_name("Blink")),1)
		_check(closed,character+" death closes new eyes")
		actor.set_dead(false)
		actor.call("play_battle_action",&"mend")
		await create_timer(.8).timeout
		_check(actor.get("battle_pose")==&"",character+" revived action recovers")
		print("PIXAL_MODEL character=",character," triangles=",triangles," bones=",rig.get_bone_count()," textured_surfaces=",textured)
		stage.queue_free()
		await process_frame
	print("PIXAL_CHARACTER_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
