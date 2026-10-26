extends SceneTree
## Graphical regression: all discovered unsafe edge samples must remain grounded.
var player: ExplorationPlayer
var world: Node3D
var camera: Camera3D
var results: Dictionary = {"edge_candidates": [], "walks": []}
const OUT := "user://prologue_repairs/"
var failures: int = 0

func _initialize() -> void:
	Engine.max_fps = 60
	preload("res://tests/qa_input_isolation.gd").isolate_joypad_motion()
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	world = Node3D.new()
	root.add_child(world)
	var map: ExplorationMap = load("res://scenes/world/mine_reference/mine.tscn").instantiate()
	world.add_child(map)
	var environment := WorldEnvironment.new()
	environment.environment = map.environment
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = map.sunlight
	world.add_child(sun)
	player = load("res://scenes/characters/player.tscn").instantiate()
	world.add_child(player)
	var old: Node3D = player.appearance
	player.visual.remove_child(old)
	old.free()
	player.appearance = load("res://scenes/characters/ren_rebuilt_visual.tscn").instantiate()
	player.visual.add_child(player.appearance)
	var collision: CollisionShape3D = player.get_node("CollisionShape3D")
	collision.shape = collision.shape.duplicate()
	(collision.shape as CapsuleShape3D).height = 1.95
	collision.position.y = .975
	player.movement.speed = 1.8
	player.movement.run_speed = 4.5
	player.movement.running_enabled = true
	player.movement.max_step_height = .18
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	camera.far = 350
	camera.make_current()
	# No movement camera: InputMap right/forward match world +X/-Z exactly.
	player.reset_to(Vector3(-36,.1,32))
	await _frames(20)
	player.set_physics_process(false)
	var space := world.get_world_3d().direct_space_state
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/mine_reference_layout.json"))
	for zone: Dictionary in layout.zones:
		var b: Array = zone.bounds
		var height: float = zone.height
		for edge: String in ["north", "south", "west", "east"]:
			var along_x := edge in ["north", "south"]
			var low: float = float(b[0] if along_x else b[2]) + .7
			var high: float = float(b[1] if along_x else b[3]) - .7
			var normal := Vector3.FORWARD if edge == "north" else (Vector3.BACK if edge == "south" else (Vector3.LEFT if edge == "west" else Vector3.RIGHT))
			var along := low
			while along <= high:
				var start := Vector3(along,height+.02,float(b[2])+.7 if edge == "north" else float(b[3])-.7) if along_x else Vector3(float(b[0])+.7 if edge == "west" else float(b[1])-.7,height+.02,along)
				var finish := start + normal * 2.4
				var query := PhysicsRayQueryParameters3D.create(finish+Vector3.UP*.3,finish-Vector3.UP*1.1,1)
				var start_query := PhysicsRayQueryParameters3D.create(start+Vector3.UP*.3,start-Vector3.UP*.3,1)
				var tr := Transform3D(Basis.IDENTITY,start)
				if not space.intersect_ray(start_query).is_empty() and space.intersect_ray(query).is_empty() and not player.test_move(tr, normal*2.4):
					results.edge_candidates.append({"zone":zone.id,"edge":edge,"start":[start.x,start.y,start.z],"direction":[normal.x,normal.y,normal.z]})
				along += .4
	print("EDGE_OPENINGS=",results.edge_candidates.size())
	if not results.edge_candidates.is_empty(): failures += 1
	# Fixed counterexamples retained even when the scan finds no new gaps.
	var regression_samples: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mine_edge_regressions.json"))
	# Physically walk every preserved unsafe sample through the real controller.
	for candidate: Dictionary in regression_samples:

		var v: Array = candidate.start
		var d: Array = candidate.direction
		var start := Vector3(v[0],v[1]+.08,v[2])
		var direction := Vector3(d[0],d[1],d[2])
		player.reset_to(start)
		player.set_physics_process(true)
		camera.position = start+Vector3(12,15,17)
		camera.look_at(start)
		await _frames(20)
		var grounded := player.is_on_floor()
		var action: StringName = &"move_right" if direction.x>0 else (&"move_left" if direction.x<0 else (&"move_back" if direction.z>0 else &"move_forward"))
		Input.action_press(action)
		Input.action_press(&"move_run")
		await _frames(60)
		Input.action_release(action)
		Input.action_release(&"move_run")
		var after := player.position
		var fallen := after.y < start.y-1.0
		results.walks.append({"zone":candidate.zone,"edge":candidate.edge,"start":str(start),"start_grounded":grounded,"after_1sec":str(after),"fallen":fallen})
		print("EDGE_WALK ", results.walks[-1])
		if fallen or not grounded:
			failures += 1
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp(OUT+"fall_"+candidate.zone+"_"+candidate.edge+".webp")
		player.set_physics_process(false)

	# Exercise four headings through the actual InputMap and turning controller.
	for action: StringName in [&"move_right", &"move_left", &"move_forward", &"move_back"]:
		player.reset_to(Vector3(-36,.1,32))
		player.set_physics_process(true)
		await _frames(20)
		Input.action_press(action)
		await _frames(30)
		Input.action_release(action)
		var expected: Vector3 = Vector3.RIGHT if action == &"move_right" else (Vector3.LEFT if action == &"move_left" else (Vector3.FORWARD if action == &"move_forward" else Vector3.BACK))
		if player.facing_direction().dot(expected) < 0.99: failures += 1
		await _frames(10)
		if player.facing_direction().dot(expected) < 0.99: failures += 1
	results.failures = failures
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(OUT+"edge_safety.webp")
	world.queue_free()
	await process_frame
	FileAccess.open(OUT+"edge_safety.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("MINE_EDGE_RESULT samples=%d new_gaps=%d failures=%d" % [regression_samples.size(), results.edge_candidates.size(), failures])
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for i: int in count: await physics_frame
