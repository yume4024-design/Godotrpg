extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(900,700)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(-.67,.95,2)
	camera.look_at(Vector3(-.67,.95,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .37
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#27323e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .3
	stage.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-30,-20,0)
	light.light_energy = .6
	var rig: Skeleton3D = hero.get("skeleton")
	for side: String in ["Left","Right"]:
		var hand: MeshInstance3D = hero.find_child("DetailedHand"+side,true,false)
		_check(hand!=null,"Separate hand mesh: "+side)
		var arrays: Array = hand.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influenced: Array[String] = []
		for index: int in range(bones.size()):
			if weights[index]<=0: continue
			var bone: int = hand.skin.get_bind_bone(bones[index])
			var name: String = rig.get_bone_name(bone) if bone>=0 else String(hand.skin.get_bind_name(bones[index]))
			if name not in influenced: influenced.append(name)
		for finger: String in ["Index","Middle","Ring","Pinky","Thumb"]:
			_check(finger+side in influenced,"Finger has skinned geometry: "+finger+side)
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/hand_open.webp")
	hero.call("set_equipment_visual",load("res://data/items/willow_staff.tres"))
	await create_timer(.15).timeout
	for name: String in ["IndexRight","MiddleRight","RingRight","PinkyRight","ThumbRight"]:
		var bone: int = rig.find_bone(name)
		_check(not rig.get_bone_pose_rotation(bone).is_equal_approx(hero.get("rest_rotations")[bone]),"Individual grip flexes: "+name)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/hand_grip.webp")
	hero.call("set_equipment_visual",null)
	await create_timer(.1).timeout
	for name: String in ["IndexRight","MiddleRight","RingRight","PinkyRight","ThumbRight"]:
		var bone: int = rig.find_bone(name)
		_check(rig.get_bone_pose_rotation(bone).is_equal_approx(hero.get("rest_rotations")[bone]),"Finger releases after unequip: "+name)
	print("FEMALE_HAND_RESULT checks=%d failures=%d" % [checks,failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
