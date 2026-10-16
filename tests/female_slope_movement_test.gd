extends SceneTree
const SURFACE_PROBE = preload("res://tests/female_slope_test.gd")
var checks: int = 0
var failures: int = 0
var player: ExplorationPlayer

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Slope movement test requires graphics")
		quit(1)
		return
	root.size = Vector2i(1000,800)
	Engine.max_fps = 60
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var floor: StaticBody3D = StaticBody3D.new()
	stage.add_child(floor)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(24,.4,24)
	collision.shape = box
	collision.position.y = -.2
	floor.add_child(collision)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = box.size
	mesh.mesh = floor_mesh
	mesh.position.y = -.2
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("759477")
	mesh.material_override = material
	floor.add_child(mesh)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = .6
	light.shadow_enabled = true
	stage.add_child(light)
	player = load("res://scenes/characters/player.tscn").instantiate()
	stage.add_child(player)
	var previous: CartoonActor = player.appearance
	player.visual.remove_child(previous)
	previous.queue_free()
	player.appearance = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	player.appearance.scale = Vector3.ONE*.82
	player.visual.add_child(player.appearance)
	var rig: Skeleton3D = player.appearance.get("skeleton")
	var body_mesh: MeshInstance3D = player.appearance.find_child("LiaBody",true,false)
	var placement: LiaFootPlacement = LiaFootPlacement.new()
	placement.actor = player.appearance
	placement.skeleton = rig
	placement.body = player
	placement.allow_motion = true
	player.appearance.add_child(placement)
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	player.movement_camera = camera
	for axis: int in range(2):
		floor.rotation_degrees = Vector3(0,0,10) if axis==0 else Vector3(10,0,0)
		var normal: Vector3 = floor.global_basis.y
		for strength: float in [.5,1.0]:
			for sign_value: float in [1.0,-1.0]:
				var start: Vector3 = Vector3(-3*sign_value,0,0) if axis==0 else Vector3(0,0,-3*sign_value)
				start.y = -(normal.x*start.x+normal.z*start.z)/normal.y+.05
				player.reset_to(start)
				await create_timer(.4).timeout
				var target: Vector3 = Vector3(-start.x,0,-start.z)
				var minimum: float = INF
				var highest_stance: float = -INF
				var grounded: int = 0
				var samples: int = 0
				for frame: int in range(300):
					var difference: Vector2 = Vector2(target.x-player.position.x,target.z-player.position.z)
					if difference.length()<.2: break
					var direction: Vector2 = difference.normalized()
					_press(Vector2(direction.x-direction.y,direction.x+direction.y)*(.70710678*strength))
					player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
					camera.position = player.position+Vector3(3,2.5,3)
					camera.look_at(player.position+Vector3.UP*.8)
					await physics_frame
					await RenderingServer.frame_post_draw
					var soles: Dictionary[String,float] = SURFACE_PROBE._soles(body_mesh,rig,normal)
					minimum = minf(minimum,minf(soles.Left,soles.Right))
					highest_stance = maxf(highest_stance,minf(soles.Left,soles.Right))
					if player.is_on_floor(): grounded += 1
					samples += 1
				_release()
				print("PHYSICAL_SLOPE axis=",axis," strength=",strength," direction=",sign_value," samples=",samples," grounded=",grounded," minimum_sole_m=",minimum," highest_stance_m=",highest_stance)
				_check(Vector2(player.position.x-target.x,player.position.z-target.z).length()<.3,"Controller reaches opposite side of ramp")
				_check(samples>20 and grounded>=samples*.95,"Capsule remains grounded on fixed slope")
				_check(minimum>-.025,"Moving imported shoes avoid deep slope penetration")
				_check(highest_stance<.045,"Moving stance foot stays within 4.5cm")
				await create_timer(.3).timeout
				_check(player.velocity.length()<.01,"Controller stops on slope")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_webp("res://artifacts/female_character/physical_slope_%d_%s_%s.webp" % [axis,str(strength),str(sign_value)])
	_release()
	stage.queue_free()
	await process_frame
	print("FEMALE_SLOPE_MOVEMENT_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _press(direction: Vector2) -> void:
	_release()
	Input.action_press(&"move_right" if direction.x>0 else &"move_left",absf(direction.x))
	Input.action_press(&"move_back" if direction.y>0 else &"move_forward",absf(direction.y))

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"move_forward",&"move_back"]: Input.action_release(action)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
