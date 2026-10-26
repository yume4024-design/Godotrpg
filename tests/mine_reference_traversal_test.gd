extends SceneTree
## Actual Player/InputMap movement on the authored physics world, without story bypasses.
var player: ExplorationPlayer
var camera: Camera3D
var checks: int = 0
var failures: int = 0
var frame_times: PackedFloat64Array = []
var last_usec: int
var rows: Array[Dictionary] = []
var map: ExplorationMap
var controls: CanvasLayer
const OUT: String = "user://mine_reference_tests/"
const ACTIONS: Array[StringName] = [&"move_left",&"move_right",&"move_forward",&"move_back",&"move_run"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	preload("res://tests/qa_input_isolation.gd").isolate_joypad_motion()
	Engine.max_fps = 60
	root.unfocusable = true
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var world := Node3D.new()
	root.add_child(world)
	map = load("res://scenes/world/mine_reference/mine.tscn").instantiate()
	world.add_child(map)
	var environment := WorldEnvironment.new()
	environment.environment = map.environment
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.light_energy = map.sunlight
	light.shadow_enabled = true
	world.add_child(light)
	player = load("res://scenes/characters/player.tscn").instantiate()
	world.add_child(player)
	var old: Node3D = player.appearance
	player.visual.remove_child(old)
	old.free()
	player.appearance = load("res://scenes/characters/ren_pixal_visual.tscn").instantiate()
	player.visual.add_child(player.appearance)
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	(collision.shape as CapsuleShape3D).height = 1.95
	collision.position.y = .975
	player.movement.speed = 1.8
	player.movement.run_speed = 4.5
	player.movement.running_enabled = true
	player.movement.max_step_height = .18
	var rig := Node3D.new()
	rig.set_script(load("res://scripts/world/fixed_camera.gd"))
	rig.set("target",player)
	rig.rotation_degrees = Vector3(-45,45,0)
	world.add_child(rig)
	camera = Camera3D.new()
	camera.position.z = 20
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.far = 300
	rig.add_child(camera)
	camera.make_current()
	player.movement_camera = camera
	player.reset_to(map.spawn_position(&"entrance"))
	await create_timer(.4).timeout
	_verify_visual_surfaces()
	_check(DisplayServer.get_name() != "headless","Graphical traversal required")
	_check(map.map_id == &"mine" and map.targets.size() == 4,"Mine identity and original interactable kinds")
	_check(player.is_on_floor(),"Entrance grounds real 1.95m player")
	var overview := Camera3D.new()
	world.add_child(overview)
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 128
	overview.far = 400
	overview.position = Vector3(105,138,138)
	overview.look_at(Vector3(0,0,2))
	overview.make_current()
	await _capture("overview")
	camera.make_current()
	if "--mine-capture-only" in OS.get_cmdline_user_args():
		await _capture_review()
		print("MINE_CAPTURE_RESULT views=18 failures=",failures)
		quit(0 if failures == 0 else 1)
		return
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/mine_reference_layout.json"))
	last_usec = Time.get_ticks_usec()
	process_frame.connect(_sample)
	for key: String in ["route","cross_route","north_route"]:
		if not await _walk(layout[key],key,key != "cross_route"): break
	if failures == 0:
		var reverse: Array = layout.north_route.duplicate(true)
		reverse.reverse()
		await _walk(reverse,"north_reverse_walk",false)
	_release()
	for p: Vector3 in [Vector3(8,0,10),Vector3(12,0,-10),Vector3(20,0,8)]:
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.4,1)
		_check(map.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"No invisible floor over underground water "+str(p))
	frame_times.sort()
	var total: float = 0
	for ms: float in frame_times: total += ms
	var result: Dictionary = {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"routes":rows,"frames":frame_times.size(),"fps":frame_times.size()*1000.0/maxf(total,1),"p95_ms":frame_times[int(ceil(frame_times.size()*.95))-1],"p99_ms":frame_times[int(ceil(frame_times.size()*.99))-1],"max_ms":frame_times[-1],"method":"Actual CharacterBody3D and InputMap feedback steering; reset only at separate route starts. No Story or reward flags set. Debug editor binary, 60 FPS cap; not a new release endurance or human playthrough."}
	process_frame.disconnect(_sample)
	FileAccess.open(OUT+"traversal.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("MINE_TRAVERSAL_RESULT checks=%d failures=%d" % [checks,failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _sample() -> void:
	var now: int = Time.get_ticks_usec()
	frame_times.append((now-last_usec)/1000.0)
	last_usec = now

func _verify_visual_surfaces() -> void:
	var paths: Dictionary = {}
	for node: Node in map.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(i)
			if material is ShaderMaterial and material.shader != null:
				paths[material.shader.resource_path] = true
	for path: String in ["mine/water.gdshader","mine/ripple.gdshader","mine/faceted_rock.gdshader","mine/wood.gdshader","mine/flame.gdshader","mine/crystal.gdshader","greystone/reference_fall.gdshader"]:
		_check(paths.has("res://assets/shaders/"+path),"Actual mine surface uses "+path)
	var quest_crystal: Node3D = map.get_node("Crystal/Prism")
	var styled: bool = false
	for node: Node in quest_crystal.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for i: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(i)
			if material is ShaderMaterial and material.shader.resource_path=="res://assets/shaders/mine/crystal.gdshader":styled=true
	_check(styled,"Interactive ancient crystal shares the mine material treatment")

func _capture_review() -> void:
	var places: Dictionary = {"camp":Vector3(-38,.1,30),"rail":Vector3(-37,3.1,-7),"crossing":Vector3(-4,3.1,0),"crystal":Vector3(-17,7.1,-32),"storage":Vector3(30,7.1,-22),"waterway":Vector3(32,.1,21),"collapse":Vector3(0,.1,36),"core":Vector3(36,.1,39),"cascade":Vector3(25,3.1,0)}
	for label: String in places:
		player.reset_to(places[label])
		for frame: int in 32: await physics_frame
		await _capture("review_"+label)
		if label=="cascade":
			await create_timer(.75).timeout
			await _capture("review_cascade_motion")
	var review := Camera3D.new()
	map.add_child(review)
	review.projection = Camera3D.PROJECTION_ORTHOGONAL
	review.size = 19.0
	review.far = 200.0
	review.global_position = Vector3(17,10,-13)
	review.look_at(Vector3(10,-1,-27))
	review.make_current()
	await _capture("review_water_detail")
	await create_timer(.75).timeout
	await _capture("review_water_detail_motion")
	review.size = 12.0
	review.global_position = Vector3(-36,8,0)
	review.look_at(Vector3(-41,5,-14))
	await _capture("review_tunnel_depth")
	for row: Array in [["camp_detail",Vector3(-25,13,50),Vector3(-35,1,37),19.0],["storage_detail",Vector3(34,16,-7),Vector3(34,8,-22),16.0],["ledge_detail",Vector3(-10,10,40),Vector3(-32,-2,35),19.0],["water_surface",Vector3(35,9,32),Vector3(28,-5,21),18.0]]:
		review.size=float(row[3])
		review.global_position=row[1]
		review.look_at(row[2])
		await _capture("review_"+String(row[0]))

func _walk(route: Array,label: String,running: bool) -> bool:
	_release()
	player.reset_to(_v(route[0])+Vector3.UP*.1)
	await create_timer(.3).timeout
	var begun: int = Time.get_ticks_usec()
	for i: int in range(1,route.size()):
		var target: Vector3 = _v(route[i])
		var start: Vector3 = player.position
		var deadline: int = Time.get_ticks_usec()+int((start.distance_to(target)/(4.5 if running else 1.8)+6)*1000000)
		while Time.get_ticks_usec() < deadline:
			var delta: Vector3 = target-player.position
			if Vector2(delta.x,delta.z).length()<.38 and absf(delta.y)<.35: break
			player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			delta.y = 0
			var right: Vector3 = camera.global_basis.x
			var back: Vector3 = camera.global_basis.z
			right.y = 0; back.y = 0
			var wanted := Vector2(delta.normalized().dot(right.normalized()),delta.normalized().dot(back.normalized()))
			Input.action_press(&"move_right",maxf(wanted.x,0))
			Input.action_press(&"move_left",maxf(-wanted.x,0))
			Input.action_press(&"move_back",maxf(wanted.y,0))
			Input.action_press(&"move_forward",maxf(-wanted.y,0))
			if running: Input.action_press(&"move_run")
			await physics_frame
		_release()
		var reached: bool = player.position.distance_to(target)<.65
		_check(reached,label+" waypoint "+str(i)+" "+str(target))
		rows.append({"route":label,"waypoint":i,"target":str(target),"actual":str(player.position),"reached":reached,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"engine_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
		if not reached:
			await _capture("failure_"+label+"_"+str(i))
			return false
		if label == "route" and i in [1,4,8,12,17,20,24]: await _capture(label+"_"+str(i))
		await physics_frame
		await physics_frame
	_check(player.is_on_floor(),label+" stops grounded")
	print("MINE_ROUTE_COMPLETE ",label," seconds=",(Time.get_ticks_usec()-begun)/1000000.0)
	return true

func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

func _release() -> void:
	for action: StringName in ACTIONS: Input.action_release(action)

func _capture(label: String) -> void:
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(OUT+label+".webp")

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)
