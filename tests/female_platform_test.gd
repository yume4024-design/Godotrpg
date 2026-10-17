extends SceneTree
const SURFACE_PROBE = preload("res://tests/female_slope_test.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1000,800)
	Engine.max_fps = 60
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var platform: AnimatableBody3D = load("res://tests/foot_test_platform.gd").new()
	stage.add_child(platform)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6,.2,6)
	collision.shape = box
	collision.position.y = -.1
	platform.add_child(collision)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	mesh.position.y = -.1
	platform.add_child(mesh)
	var player: ExplorationPlayer = load("res://scenes/characters/player.tscn").instantiate()
	stage.add_child(player)
	var original: CartoonActor = player.appearance
	player.visual.remove_child(original)
	original.queue_free()
	player.appearance = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	player.appearance.scale = Vector3.ONE*.82
	player.visual.add_child(player.appearance)
	player.appearance.call("set_animation_physics",true)
	player.input_component.enabled = false
	player.reset_to(Vector3(0,.05,0))
	var rig: Skeleton3D = player.appearance.get("skeleton")
	var body: MeshInstance3D = player.appearance.find_child("LiaBody",true,false)
	var placement: LiaFootPlacement = LiaFootPlacement.new()
	placement.actor = player.appearance
	placement.skeleton = rig
	placement.body = player
	placement.allow_motion = true
	placement.physics_pose = true
	player.appearance.add_child(placement)
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3
	player.movement_camera = camera
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = .6
	light.shadow_enabled = true
	await create_timer(.4).timeout
	_check(player.is_on_floor(),"Controller starts on animatable platform")
	platform.set("moving",true)
	var minimum: float = INF
	var highest_stance: float = -INF
	var horizontal_error: float = 0
	var grounded: int = 0
	for frame: int in range(360):
		camera.position = player.position+Vector3(2.8,1.8,3)
		camera.look_at(player.position+Vector3.UP*.8)
		await physics_frame
		await RenderingServer.frame_post_draw
		var soles: Dictionary[String,float] = SURFACE_PROBE._soles(body,rig,Vector3.UP)
		minimum = minf(minimum,minf(soles.Left,soles.Right)-platform.position.y)
		highest_stance = maxf(highest_stance,minf(soles.Left,soles.Right)-platform.position.y)
		horizontal_error = maxf(horizontal_error,absf(player.position.x-platform.position.x))
		if player.is_on_floor(): grounded += 1
		if frame==75: root.get_texture().get_image().save_webp("res://artifacts/female_character/platform_ride.webp")
	print("MOVING_PLATFORM minimum_sole_m=",minimum," highest_stance_m=",highest_stance," horizontal_error_m=",horizontal_error," grounded=",grounded," samples=360")
	_check(grounded>=342,"Controller remains grounded while platform moves")
	_check(horizontal_error<.08,"Platform carries controller horizontally")
	_check(minimum>-.025,"Feet avoid moving platform penetration")
	_check(highest_stance<.045,"Feet remain close to moving platform")
	platform.set("moving",false)
	player.input_component.enabled = true
	for frame: int in range(65):
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.action_press(&"move_right",.70710678)
		Input.action_press(&"move_back",.70710678)
		await physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"move_back")
	await create_timer(.3).timeout
	_check(not player.is_on_floor() and placement.last_target_errors.is_empty(),"Walking off platform releases IK")
	player.input_component.enabled = false
	player.reset_to(platform.position+Vector3.UP*.05)
	await create_timer(.5).timeout
	_check(player.is_on_floor(),"Controller can return to stopped platform")
	var reference: WeakRef = weakref(platform)
	platform.queue_free()
	await create_timer(.5).timeout
	_check(reference.get_ref()==null and placement.last_target_errors.is_empty(),"Removing occupied platform releases support safely")
	var finite: bool = true
	for index: int in range(rig.get_bone_count()): finite = finite and rig.get_bone_global_pose(index).is_finite()
	_check(finite,"Platform removal leaves finite bone transforms")
	stage.queue_free()
	await process_frame
	print("FEMALE_PLATFORM_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
