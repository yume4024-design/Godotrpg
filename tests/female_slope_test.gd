extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1000,800)
	Engine.max_fps = 60
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var floor: StaticBody3D = StaticBody3D.new()
	stage.add_child(floor)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(5,.2,5)
	collider.shape = box
	collider.position.y = -.1
	floor.add_child(collider)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var floor_box: BoxMesh = BoxMesh.new()
	floor_box.size = box.size
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -.1
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("687e6e")
	floor_mesh.material_override = material
	floor.add_child(floor_mesh)
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.6,1.5,3)
	camera.look_at(Vector3(0,.85,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = .6
	light.shadow_enabled = true
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	var rig: Skeleton3D = hero.get("skeleton")
	var placement: LiaFootPlacement = LiaFootPlacement.new()
	placement.skeleton = rig
	placement.actor = hero
	hero.add_child(placement)
	var body: MeshInstance3D = hero.find_child("LiaBody",true,false)
	for orientation: Vector3 in [Vector3.ZERO,Vector3(10,0,0),Vector3(-10,0,0),Vector3(0,0,10),Vector3(0,0,-10)]:
		floor.rotation_degrees = orientation
		await create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		var normal: Vector3 = floor.global_basis.y
		var lowest: Dictionary[String,float] = _soles(body,rig,normal)
		print("SLOPE_RESULT degrees=",orientation," soles_m=",lowest," ankle_errors=",placement.last_target_errors)
		_check(placement.last_target_errors.size()==2,"Both foot rays find slope")
		for side: String in lowest:
			_check(lowest[side]>-.025 and lowest[side]<.025,"Sole stays near slope: "+side)
			_check(placement.last_target_errors.get(side,INF)<.01,"Two-bone ankle reaches target: "+side)
		_check(hero.position==Vector3.ZERO,"Foot placement leaves actor position unchanged")
		root.get_texture().get_image().save_webp("res://artifacts/female_character/slope_%d_%d.webp" % [orientation.x,orientation.z])
	placement.allow_motion = true
	for actor_scale: float in [1.0,.82]:
		hero.scale = Vector3.ONE*actor_scale
		for angle: Vector3 in [Vector3(10,0,0),Vector3(0,0,10)]:
			floor.rotation_degrees = angle
			for amount: float in [.4,1.0]:
				hero.set_motion(amount)
				await create_timer(.25).timeout
				var minimum: float = INF
				var highest_stance: float = -INF
				var maximum_lift: Dictionary[String,float] = {"Left":0,"Right":0}
				for sample: int in range(72):
					await process_frame
					await RenderingServer.frame_post_draw
					var soles: Dictionary[String,float] = _soles(body,rig,floor.global_basis.y)
					minimum = minf(minimum,minf(soles.Left,soles.Right))
					highest_stance = maxf(highest_stance,minf(soles.Left,soles.Right))
					for side: String in soles: maximum_lift[side] = maxf(maximum_lift[side],soles[side])
				print("MOVING_SLOPE scale=",actor_scale," degrees=",angle," motion=",amount," minimum_m=",minimum," highest_stance_m=",highest_stance," maximum_lift_m=",maximum_lift)
				_check(minimum>-.025,"Moving soles avoid deep penetration")
				_check(highest_stance<.035,"At least one stance foot stays near ground")
				_check(maximum_lift.Left>.03 and maximum_lift.Right>.03,"Both swing feet retain lift")
				_check(hero.position==Vector3.ZERO,"Moving IK leaves actor transform unchanged")
				root.get_texture().get_image().save_webp("res://artifacts/female_character/moving_slope_%d_%d_%s_%s.webp" % [angle.x,angle.z,str(actor_scale),str(amount)])
	hero.set_motion(0)
	await create_timer(.3).timeout
	hero.set_dead(true)
	await process_frame
	await process_frame
	_check(placement.last_target_errors.is_empty(),"Dead actor receives no IK")
	hero.set_dead(false)
	hero.call("play_battle_action",&"mend")
	await create_timer(.1).timeout
	_check(placement.last_target_errors.is_empty(),"Battle pose receives no IK")
	await create_timer(.8).timeout
	collider.disabled = true
	await physics_frame
	await physics_frame
	await process_frame
	_check(placement.last_target_errors.is_empty(),"Missing ground safely disables IK")
	stage.queue_free()
	await process_frame
	print("FEMALE_SLOPE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _soles(body: MeshInstance3D,rig: Skeleton3D,normal: Vector3) -> Dictionary[String,float]:
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size()/vertices.size()
	var result: Dictionary[String,float] = {"Left":INF,"Right":INF}
	var transforms: Array[Transform3D] = []
	for bind: int in range(body.skin.get_bind_count()):
		var joint: int = body.skin.get_bind_bone(bind)
		if joint<0: joint = rig.find_bone(body.skin.get_bind_name(bind))
		transforms.append(rig.get_bone_global_pose(joint)*body.skin.get_bind_pose(bind))
	for index: int in range(vertices.size()):
		if vertices[index].y>.13: continue
		var point: Vector3 = Vector3.ZERO
		for influence: int in range(influences):
			var offset: int = index*influences+influence
			if weights[offset]>0: point += (transforms[bones[offset]]*vertices[index])*weights[offset]
		var side: String = "Left" if vertices[index].x>0 else "Right"
		result[side] = minf(result[side],normal.dot(rig.global_transform*point))
	return result

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
