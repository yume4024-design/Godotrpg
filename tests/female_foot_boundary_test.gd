extends SceneTree
const SURFACE_PROBE = preload("res://tests/female_slope_test.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1000,800)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var floor: StaticBody3D = StaticBody3D.new()
	stage.add_child(floor)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5,.2,5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -.1
	floor.add_child(collision)
	var surface: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = shape.size
	surface.mesh = mesh
	surface.position.y = -.1
	floor.add_child(surface)
	var ignored: StaticBody3D = StaticBody3D.new()
	ignored.collision_layer = 4
	stage.add_child(ignored)
	var ignored_shape: CollisionShape3D = CollisionShape3D.new()
	var ignored_box: BoxShape3D = BoxShape3D.new()
	ignored_box.size = Vector3(2,.1,2)
	ignored_shape.shape = ignored_box
	ignored_shape.position.y = .1
	ignored.add_child(ignored_shape)
	var proxy: StaticBody3D = StaticBody3D.new()
	proxy.collision_layer = 2
	proxy.collision_mask = 1
	stage.add_child(proxy)
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	var rig: Skeleton3D = hero.get("skeleton")
	var body: MeshInstance3D = hero.find_child("LiaBody",true,false)
	var placement: LiaFootPlacement = LiaFootPlacement.new()
	placement.actor = hero
	placement.skeleton = rig
	placement.body = proxy
	hero.add_child(placement)
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
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	var soles: Dictionary[String,float] = SURFACE_PROBE._soles(body,rig,Vector3.UP)
	print("BOUNDARY_LAYER_MASK soles=",soles)
	_check(absf(soles.Left)<.015 and absf(soles.Right)<.015,"Visual feet ignore non-colliding layer 4")
	proxy.collision_mask = 5
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	soles = SURFACE_PROBE._soles(body,rig,Vector3.UP)
	_check(soles.Left>.10 and soles.Right>.10,"Explicit body mask can opt into layer 4")
	proxy.collision_mask = 1
	ignored.collision_layer = 0
	floor.rotation_degrees.z = 25
	await create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	print("BOUNDARY_25_DEGREES errors=",placement.last_target_errors)
	_check(placement.last_target_errors.size()==2 and placement.last_target_errors.Left<.015 and placement.last_target_errors.Right<.015,"Both ankles reach a 25 degree slope")
	soles = SURFACE_PROBE._soles(body,rig,floor.global_basis.y)
	print("BOUNDARY_25_DEGREES soles=",soles)
	_check(absf(soles.Left)<.015 and absf(soles.Right)<.015,"Skinned soles stay on the 25 degree plane")
	camera.position = Vector3(-2.6,1.6,3)
	camera.look_at(Vector3(0,.75,0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/foot_boundary_25.webp")
	floor.rotation_degrees.z = 35
	await create_timer(.5).timeout
	_check(placement.last_target_errors.is_empty(),"Unsupported 35 degree surface is not solved")
	floor.rotation_degrees = Vector3.ZERO
	floor.position.x = 1
	shape.size.x = 2
	mesh.size = shape.size
	await create_timer(.6).timeout
	_check(placement.last_target_errors.size()==1 and placement.last_target_errors.has("Left"),"Ledge only solves the supported foot")
	var right: int = rig.find_bone("FootRight")
	_check(rig.get_bone_global_pose(right).origin.distance_to(rig.get_bone_global_rest(right).origin)<.005,"Unsupported foot retains original pose")
	floor.position.x = 8
	await create_timer(.5).timeout
	_check(placement.last_target_errors.is_empty(),"Void fades back to original animation")
	var finite: bool = true
	for index: int in range(rig.get_bone_count()): finite = finite and rig.get_bone_global_pose(index).is_finite()
	_check(finite,"Boundary changes leave finite skeleton transforms")
	_check(hero.position==Vector3.ZERO,"Boundary solver never moves the actor")
	stage.queue_free()
	await process_frame
	print("FEMALE_FOOT_BOUNDARY_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
