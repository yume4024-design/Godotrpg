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
	var other: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(other)
	other.position.x = 3
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.7,2)
	camera.look_at(Vector3(0,1.7,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .55
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#27323e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .6
	stage.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-30,-20,0)
	var eyes: Array = hero.get("_blink_meshes")
	_check(eyes.size()==8,"Eight eye surfaces have imported Blink morph")
	_check(hero.find_child("SmileLine",true,false)!=null,"Lip line imported")
	await create_timer(.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/face_open.webp")
	var peak: float = 0.0
	var captured: bool = false
	var until: int = Time.get_ticks_msec()+4400
	while Time.get_ticks_msec()<until:
		await process_frame
		var closure: float = eyes[0].get_blend_shape_value(eyes[0].find_blend_shape_by_name("Blink"))
		peak = maxf(peak,closure)
		if closure > .88 and not captured:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/female_character/face_blink.webp")
			captured = true
	_check(peak>.88 and captured,"Natural timer closes eyelids")
	_check(eyes[0].get_blend_shape_value(eyes[0].find_blend_shape_by_name("Blink"))<.01,"Eyes reopen after natural blink")
	hero.set_dead(true)
	for mesh: MeshInstance3D in eyes:
		_check(is_equal_approx(mesh.get_blend_shape_value(mesh.find_blend_shape_by_name("Blink")),1.0),"Dead eye surface closes: "+mesh.name)
	var other_eye: MeshInstance3D = other.get("_blink_meshes")[0]
	_check(other_eye.get_blend_shape_value(other_eye.find_blend_shape_by_name("Blink"))<.01,"Second instance does not inherit dead eyelids")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/face_closed.webp")
	hero.set_dead(false)
	await create_timer(.2).timeout
	_check(eyes[0].get_blend_shape_value(eyes[0].find_blend_shape_by_name("Blink"))<.01,"Revived eye surface reopens")
	print("FEMALE_FACE_RESULT checks=%d failures=%d peak=%.3f" % [checks,failures,peak])
	stage.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
