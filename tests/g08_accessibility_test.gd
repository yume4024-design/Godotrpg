extends SceneTree
## Graphical regression: real capsule motion and actual mine timber meshes.
var checks: int = 0
var failures: int = 0
var stage: Node3D
var player: ExplorationPlayer
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])

func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	stage.add_child(body)
	body.position = pos
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var geometry: BoxMesh = BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	body.add_child(mesh)
	return body

func _move(direction: Vector2, frames: int) -> void:
	for frame: int in range(frames):
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		if direction.y < 0: Input.action_press(&"move_forward", -direction.y)
		if direction.y > 0: Input.action_press(&"move_back", direction.y)
		if direction.x < 0: Input.action_press(&"move_left", -direction.x)
		if direction.x > 0: Input.action_press(&"move_right", direction.x)
		await physics_frame
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)

func _place(pos: Vector3) -> void:
	player.reset_to(pos)
	await _move(Vector2.ZERO, 12)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/g082/" + label + ".webp")

func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1000, 760)
	DirAccess.make_dir_recursive_absolute("res://artifacts/g082")
	stage = Node3D.new()
	root.add_child(stage)
	_box(Vector3(0,-.1,0), Vector3(20,.2,20))
	for index: int in range(3):
		var height: float = .12*(index+1)
		_box(Vector3(0,height/2,1-index), Vector3(4,height,1))
	player = load("res://scenes/characters/player.tscn").instantiate()
	stage.add_child(player)
	# Opt-in only; baseline has no stair support yet.
	if "max_step_height" in player.movement: player.movement.set("max_step_height", .18)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5,4,6)
	camera.look_at(Vector3(0,.6,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45,-25,0)
	for hero: String in ["ren", "lia"]:
		var old: Node3D = player.appearance
		player.visual.remove_child(old)
		old.queue_free()
		player.appearance = load("res://scenes/characters/%s_pixal_visual.tscn" % hero).instantiate()
		player.appearance.scale = Vector3.ONE*.82
		player.visual.add_child(player.appearance)
		await _place(Vector3(0,0,3))
		await _move(Vector2(0,-1), 50)
		await _move(Vector2.ZERO, 8)
		print("STAIRS ",hero," top=",player.position)
		_check(player.position.z < -.55 and player.position.y > .30 and player.is_on_floor(), hero + " climbs three 12cm solid risers")
		var stopped: Vector3 = player.position
		await _move(Vector2.ZERO, 10)
		_check(player.position.distance_to(stopped) < .005, hero + " stops without drifting")
		await _capture(hero + "-steps")
		await _move(Vector2(0,1), 50)
		await _move(Vector2.ZERO, 12)
		_check(player.position.z > 2.5 and absf(player.position.y) < .02 and player.is_on_floor(), hero + " descends to floor")
	var wall: StaticBody3D = _box(Vector3(6,.5,1),Vector3(3,1,1))
	await _place(Vector3(6,0,3))
	await _move(Vector2(0,-1),45)
	_check(player.position.z > 1.7 and player.position.y < .02, "1m obstacle cannot be climbed")
	wall.queue_free()
	var ceiling: StaticBody3D = _box(Vector3(0,1.72,1.8),Vector3(4,.1,1.2))
	await _place(Vector3(0,0,3))
	await _move(Vector2(0,-1),35)
	_check(player.position.z > 1.6 and player.position.y < .04, "low ceiling blocks step without penetration")
	ceiling.queue_free()
	await process_frame
	var high_step: StaticBody3D = _box(Vector3(6,.11,1),Vector3(3,.22,1))
	await _place(Vector3(6,0,3))
	await _move(Vector2(0,-1),40)
	_check(player.position.z > 1.7 and player.position.y < .02, "22cm riser exceeds 18cm limit")
	high_step.queue_free()
	await process_frame
	player.movement.set("max_step_height",0.0)
	await _place(Vector3(0,0,3))
	await _move(Vector2(0,-1),35)
	_check(player.position.z > 1.7 and player.position.y < .02, "legacy disabled setting preserves previous collision")
	player.movement.set("max_step_height",.18)
	await _place(Vector3(-1,0,3))
	await _move(Vector2(.25,-1).normalized(),50)
	_check(player.position.z < -.5 and player.position.y > .3, "diagonal stair ascent")
	await _place(Vector3(6,0,3))
	var start: Vector3 = player.position
	await _move(Vector2(0,-1),20)
	_check(absf(player.position.distance_to(start)-1.5) < .08, "flat-ground speed stays 4.5m/s")
	await _mine()
	print("G082_RESULT checks=%d failures=%d" % [checks, failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _mine() -> void:
	# Added once the production visibility component exists.
	var path: String = "res://scripts/world/exploration_occlusion.gd"
	if not ResourceLoader.exists(path):
		_check(false, "mine occlusion component available")
		return
	var mine: ExplorationMap = load("res://scenes/world/expanded/mine.tscn").instantiate()
	stage.add_child(mine)
	mine.position.x = 60
	var component: Node = load(path).new()
	component.set("target", player)
	component.set("camera", camera)
	stage.add_child(component)
	component.call("set_map", mine)
	var beam: MeshInstance3D = mine.get_node("Beam2")
	_check(mine.get_tree().get_nodes_in_group(&"exploration_occluder").size() == 11, "three authored and eight expanded mine beams registered")
	player.reset_to(Vector3(58,0,-2))
	camera.position = player.position + Vector3(10,15,10)
	camera.look_at(player.position+Vector3.UP*.8)
	await _move(Vector2.ZERO,12)
	await _capture("mine-before")
	component.set("enabled", true)
	await _move(Vector2.ZERO,12)
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "foreground beam removed from character silhouette; shadow retained")
	await _capture("mine-after")
	player.hide()
	await _move(Vector2.ZERO,3)
	await process_frame
	await RenderingServer.frame_post_draw
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "battle-hidden exploration player restores beam")
	player.show()
	await _move(Vector2.ZERO,3)
	component.set("enabled",false)
	await _move(Vector2.ZERO,3)
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "disabling component restores beam")
	component.set("enabled",true)
	player.reset_to(Vector3(70,0,-10))
	camera.position = player.position + Vector3(10,15,10)
	camera.look_at(player.position+Vector3.UP*.8)
	await _move(Vector2.ZERO,12)
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "unblocked beam restored")
	player.reset_to(Vector3(58,0,-2))
	camera.position = player.position + Vector3(10,15,10)
	camera.look_at(player.position+Vector3.UP*.8)
	await _move(Vector2.ZERO,3)
	component.call("set_map", null)
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "map switch restores original rendering")
	component.queue_free()
	mine.queue_free()
