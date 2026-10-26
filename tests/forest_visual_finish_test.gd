extends "res://tests/mine_reference_traversal_test.gd"
## Visual-only forest changes compared with a frozen physical/interaction baseline.
const OUTPUT: String = "user://forest_visual_finish/"
const BASELINE: String = "res://source_assets/forest_visual_finish_20261026/baseline.json"
var recording: bool = false
var plant_statistics: Dictionary = {}
var output_path: String = OUTPUT

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output=user://"):
			output_path=argument.trim_prefix("--output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output_path)
	preload("res://tests/qa_input_isolation.gd").isolate_joypad_motion()
	root.unfocusable = true
	Engine.max_fps = 60
	_run.call_deferred()

func _snapshot() -> Dictionary:
	var collisions: Array[String] = []
	for node: Node in map.find_children("*","CollisionShape3D",true,false):
		var c := node as CollisionShape3D
		collisions.append(var_to_bytes([c.global_transform,c.shape.get_class(),c.shape.get_debug_mesh().get_aabb(),c.disabled,(c.get_parent() as CollisionObject3D).collision_layer,(c.get_parent() as CollisionObject3D).collision_mask]).hex_encode())
	collisions.sort()
	var targets: Dictionary = {}
	for target: WorldInteractable in map.targets:
		targets[String(target.interaction_id)]=var_to_bytes([target.global_transform,target.kind,target.battle_id,target.required_flag]).hex_encode()
	var markers: Dictionary = {}
	for node: Node in map.find_children("*","Marker3D",true,false):markers[String(map.get_path_to(node))]=var_to_bytes((node as Node3D).global_transform).hex_encode()
	var protected: Dictionary = {}
	for path: String in ["scenes/main/main.tscn","scenes/world/forest.tscn","scripts/world/expanded_wilderness.gd","scripts/save/save_codec.gd","data/story/prologue_events.json"]:
		protected[path]=FileAccess.get_file_as_string("res://"+path).replace("\r\n","\n").sha256_text()
	return {"collisions":collisions,"targets":targets,"markers":markers,"protected":protected}

func _run() -> void:
	recording="--baseline" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	map=load("res://scenes/world/expanded/forest.tscn").instantiate()
	world.add_child(map)
	var template: Node = load("res://scenes/main/main.tscn").instantiate()
	var env := WorldEnvironment.new()
	env.environment=map.environment if map.environment != null else (template.get_node("WorldEnvironment") as WorldEnvironment).environment
	template.free()
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-35,0)
	light.light_energy=map.sunlight
	light.shadow_enabled=true
	world.add_child(light)
	player=load("res://scenes/characters/player.tscn").instantiate()
	world.add_child(player)
	var old: Node3D=player.appearance
	player.visual.remove_child(old)
	old.free()
	player.appearance=load("res://scenes/characters/ren_pixal_visual.tscn").instantiate()
	player.visual.add_child(player.appearance)
	player.movement.speed=1.8
	player.movement.run_speed=4.5
	player.movement.running_enabled=true
	var rig := Node3D.new()
	rig.set_script(load("res://scripts/world/fixed_camera.gd"))
	rig.set("target",player)
	rig.rotation_degrees=Vector3(-45,45,0)
	world.add_child(rig)
	camera=Camera3D.new()
	camera.position.z=20
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=12
	root.content_scale_size=root.size
	rig.add_child(camera)
	camera.make_current()
	player.movement_camera=camera
	player.reset_to(map.spawn_position(&"entrance"))
	await create_timer(.5).timeout
	_check(DisplayServer.get_name()!="headless","Native forest visual/traversal process")
	var snapshot: Dictionary=_snapshot()
	if recording:
		_check(not FileAccess.file_exists(BASELINE),"Do not overwrite frozen forest baseline")
		if failures==0:FileAccess.open(BASELINE,FileAccess.WRITE).store_string(JSON.stringify(snapshot,"  "))
	else:
		var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		for key: String in baseline:_check(snapshot[key]==baseline[key],"Preserve forest "+key)
		_check(map.has_node("Presentation"),"Independent forest presentation installed")
		_verify_presentation()
	last_usec=Time.get_ticks_usec()
	process_frame.connect(_sample)
	await _walk([[-7,0,0],[-2,0,0],[2,0,0],[7,0,0],[7,0,2],[9,0,2]],"forest_story",true)
	await _walk([[-18,0,-13],[-15,0,-17],[15,0,-17],[18,0,-13],[18,0,13],[15,0,17],[-15,0,17],[-18,0,13],[-18,0,-13]],"forest_loop",true)
	if not recording:
		await _capture("player_trail")
		await _walk([[9,0,2],[7,0,2],[7,0,0],[2,0,0],[-2,0,0],[-7,0,0]],"forest_story_walk_back",false)
	process_frame.disconnect(_sample)
	if not recording:
		player.reset_to(map.spawn_position(&"entrance"))
		await create_timer(.3).timeout
		await _capture("player_entrance")
	var review := Camera3D.new()
	world.add_child(review)
	review.projection=Camera3D.PROJECTION_ORTHOGONAL
	review.far=220
	review.make_current()
	for row: Array in [["overview",Vector3(55,77.78,55),Vector3.ZERO,82.0],["entrance",Vector3(4,12,12),Vector3(-7,0,0),16.0],["mine_way",Vector3(20,13,14),Vector3(8,1,1),16.0],["north_trail",Vector3(1,13,-4),Vector3(-10,0,-17),18.0],["west_border",Vector3(-13,14,-3),Vector3(-27,0,-14),18.0],["south_edge",Vector3(16,13,36),Vector3(7,0,25),18.0]]:
		review.global_position=row[1]
		review.look_at(row[2])
		review.size=float(row[3])
		await _capture(String(row[0]))
	frame_times.sort()
	var result: Dictionary={"checks":checks,"failures":failures,"baseline":recording,"snapshot":snapshot,"plants":plant_statistics,"routes":rows,"frames":frame_times.size(),"mean_ms":_mean(frame_times),"max_ms":frame_times[-1],"p95_ms":frame_times[int(frame_times.size()*.95)],"p99_ms":frame_times[int(frame_times.size()*.99)],"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string}
	FileAccess.open(output_path+("before.json" if recording else "after.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FOREST_VISUAL_FINISH_RESULT checks=%d failures=%d baseline=%s"%[checks,failures,recording])
	world.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _mean(values: PackedFloat64Array) -> float:
	var total: float=0
	for value: float in values:total+=value
	return total/maxi(values.size(),1)

func _verify_presentation() -> void:
	var ground := map.get_node("Ground/Mesh") as MeshInstance3D
	_check(ground.get_active_material(0) is ShaderMaterial,"Actual forest floor has surface grain")
	var softened_trails: int=0
	for node: Node in map.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		var material: Material=visual.get_active_material(0)
		if material is ShaderMaterial and material.shader.resource_path=="res://assets/shaders/forest/trail.gdshader":softened_trails+=1
	_check(softened_trails==9,"Central and expanded trails share nine soft edge surfaces")
	var flat_trails: bool=true
	var floor_y: float=(ground.global_transform*ground.get_aabb()).end.y
	for node: Node in map.get_node("Presentation").find_children("TrailSurface*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		flat_trails=flat_trails and visual.mesh is PlaneMesh and is_equal_approx(visual.global_position.y,floor_y+.005)
	_check(flat_trails and softened_trails==9,"Road display has no raised side walls or height seams")
	var flat_edges: int=0
	var hidden_edge_boxes: int=0
	for node: Node in map.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		var path: String=String(map.get_path_to(visual))
		if path.begins_with("Scenery/EdgeGround/") and visual.mesh is BoxMesh and not visual.visible:
			hidden_edge_boxes+=1
		if String(visual.name).begins_with("EdgeGroundSurface_"):
			flat_edges+=1
			var material: Material=visual.get_active_material(0)
			flat_trails=flat_trails and visual.mesh is PlaneMesh and is_equal_approx(visual.global_position.y,floor_y+.006)
			flat_trails=flat_trails and material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path=="res://assets/shaders/greystone/ground.gdshader"
	_check(flat_edges==4 and hidden_edge_boxes==4 and flat_trails,"Perimeter ground joins the floor with four flat matching surfaces")
	var encroaching: int=0
	var border_surfaces: int=0
	for node: Node in map.get_node("Presentation/Border").find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		border_surfaces+=mesh.mesh.get_surface_count()
		for surface: int in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var world: Vector3=mesh.global_transform*vertex
				if absf(world.x)<24.8 and absf(world.z)<24.8:encroaching+=1
	_check(encroaching==0,"Backdrop vertices remain outside playable boundary")
	_check(border_surfaces<=5,"Backdrop remains batched into at most five surfaces")
	var blocked: int=0
	var instances: int=0
	for node: Node in map.get_node("Presentation").find_children("*","MultiMeshInstance3D",true,false):
		var batch := node as MultiMeshInstance3D
		plant_statistics[String(batch.name)]={"instances":batch.multimesh.instance_count,"mesh_triangles":batch.multimesh.mesh.get_faces().size()/3}
		for index: int in batch.multimesh.instance_count:
			instances+=1
			var p: Vector3=batch.multimesh.get_instance_transform(index).origin
			if absf(p.z)<2.5 or absf(absf(p.z)-17)<2.5 or absf(absf(p.x)-18)<2.5:blocked+=1
			for target: WorldInteractable in map.targets:
				if p.distance_to(target.position)<2.6:blocked+=1
	_check(instances>0 and blocked==0,"Plants leave main trail and interaction reserves clear")

func _capture(label: String) -> void:
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(output_path+("before_" if recording else "after_")+label+".webp")
