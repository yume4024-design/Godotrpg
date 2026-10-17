extends SceneTree
## Functional step gate: failure never enables IK or changes the controller.
func _initialize() -> void:
	_run.call_deferred()

func _box(parent: Node3D,position: Vector3,size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	parent.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var geometry: BoxMesh = BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	body.add_child(mesh)

func _run() -> void:
	root.size = Vector2i(1000,800)
	Engine.max_fps = 60
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	_box(stage,Vector3(0,-.1,0),Vector3(12,.2,12))
	for step: int in range(3):
		var height: float = .12*(step+1)
		_box(stage,Vector3(0,height*.5,1-step),Vector3(4,height,1))
	var player: ExplorationPlayer = load("res://scenes/characters/player.tscn").instantiate()
	stage.add_child(player)
	var original: CartoonActor = player.appearance
	player.visual.remove_child(original)
	original.queue_free()
	player.appearance = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	player.appearance.scale = Vector3.ONE*.82
	player.visual.add_child(player.appearance)
	player.appearance.call("set_animation_physics",true)
	var placement: LiaFootPlacement = LiaFootPlacement.new()
	placement.actor = player.appearance
	placement.skeleton = player.appearance.get("skeleton")
	placement.body = player
	placement.allow_motion = true
	placement.physics_pose = true
	player.appearance.add_child(placement)
	player.reset_to(Vector3(0,0,3))
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(4,2.5,4)
	camera.look_at(Vector3(0,.8,1.5))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = .6
	sun.shadow_enabled = true
	await create_timer(.4).timeout
	for frame: int in range(120):
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.action_press(&"move_forward")
		await physics_frame
	Input.action_release(&"move_forward")
	await create_timer(.3).timeout
	var traversed: bool = player.position.z<-.6 and player.position.y>.3
	var finite: bool = true
	for bone: int in range(placement.skeleton.get_bone_count()):
		finite = finite and placement.skeleton.get_bone_global_pose(bone).is_finite()
	print("STEP_ACCEPTANCE riser_m=0.12 traversal_passed=",traversed," final_position=",player.position," finite_skeleton=",finite," grounded=",player.is_on_floor())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/cp23_steps.webp")
	stage.queue_free()
	await process_frame
	quit(1 if not finite else (0 if traversed else 2))
