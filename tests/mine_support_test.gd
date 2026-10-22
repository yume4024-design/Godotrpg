extends SceneTree
## Standalone geometry/physics acceptance. No game managers or save file.
const ASSET: PackedScene = preload("res://scenes/world/greystone/props/mine_support_frame.tscn")
const OUT: String = "res://artifacts/env02_mine_support"
const LIMIT: int = 1200
var checks: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var graphical: bool = false
var movement: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _meshes(instance: Node) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in instance.find_children("*","MeshInstance3D",true,false): result[str(node.name)] = node
	return result

func _capture(name: String) -> void:
	if not graphical: return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(910,512,Image.INTERPOLATE_LANCZOS)
	_check(picture.save_webp(OUT+"/"+name+".webp",false,.93) == OK,"Native capture "+name)
	captures.append(name)

func _walk(body: CharacterBody3D, origin: Vector3, direction: float, speed: float, frames: int, label: String) -> void:
	body.position = origin
	body.velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	await physics_frame
	for index: int in range(frames):
		await physics_frame
		body.velocity = Vector3(0,-.5,direction*speed)
		body.move_and_slide()
	movement.append({"case":label,"position":body.position,"speed":speed,"frames":frames})
	_check(body.position.is_finite() and absf(body.position.y) < .03,label+" stays finite and grounded")

func _run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	if graphical:
		_check(root.unfocusable,"Native asset QA window does not request input focus")
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world := Node3D.new()
	root.add_child(world)
	var first: Node3D = ASSET.instantiate()
	world.add_child(first)
	var meshes: Dictionary = _meshes(first)
	_check(meshes.size() == 3 and meshes.has_all(["PostLeft","PostRight","Beam"]),"Three named rigid model parts")
	var expected: Dictionary = {
		"PostLeft": AABB(Vector3(-2.325,0,-.125),Vector3(.25,2.4,.25)),
		"PostRight": AABB(Vector3(2.075,0,-.125),Vector3(.25,2.4,.25)),
		"Beam": AABB(Vector3(-2.35,2.375,-.15),Vector3(4.7,.25,.3)),
	}
	var triangles: int = 0
	var materials: Dictionary = {}
	for name: String in meshes:
		var node: MeshInstance3D = meshes[name]
		var bounds: AABB = expected[name]
		var inside: bool = true
		var finite: bool = true
		_check(node.mesh.get_surface_count() == 3,name+" has three palette surfaces")
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size())/3
			for vertex: Vector3 in vertices:
				var point: Vector3 = first.to_local(node.to_global(vertex))
				finite = finite and point.is_finite()
				inside = inside and bounds.grow(.00002).has_point(point)
			var material: StandardMaterial3D = node.mesh.surface_get_material(surface)
			_check(material != null and material.albedo_texture == null,name+" uses texture-free palette")
			if material != null:
				materials[material.resource_path] = true
				_check(material.resource_path in ["res://assets/materials/greystone/props/wood.tres","res://assets/materials/greystone/props/wood_cut.tres","res://assets/materials/greystone/props/iron.tres"],"Shared approved material resource")
		_check(finite,name+" vertices are finite")
		_check(inside,name+" geometry remains within its original convex box")
	_check(triangles == 804 and triangles <= LIMIT,"Actual imported triangle count and per-frame budget")
	_check(materials.size() == 3,"Three shared palette materials")
	var visual: Node3D = first.get_node("Visual")
	_check(visual.get_node_or_null(visual.get_meta("beam_node")) == meshes.get("Beam"),"Declared visual-only beam path resolves to the actual imported mesh")
	var shapes: Array[Node] = first.find_children("*","CollisionShape3D",true,false)
	_check(shapes.size() == 2,"Only two simplified post colliders; no new overhead collision")
	for shape: CollisionShape3D in shapes:
		_check(shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(.25,2.4,.25)),"Original collision dimensions")
		_check(shape.scale.is_equal_approx(Vector3.ONE),"Collision resource has no scaled shape")
	_check((first as StaticBody3D).collision_layer == 1,"Environment collision layer")
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(28,.3,20)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.15
	floor.add_child(floor_shape)
	world.add_child(floor)
	var floor_visual := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = floor_box.size
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(.28,.32,.31)
	floor_mesh.material = ground
	floor_visual.mesh = floor_mesh
	floor_visual.position.y = -.15
	floor.add_child(floor_visual)
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.95
	capsule.radius = .32
	var actor_shape := CollisionShape3D.new()
	actor_shape.shape = capsule
	actor_shape.position.y = .975
	body.add_child(actor_shape)
	world.add_child(body)
	await _walk(body,Vector3(0,.01,2.6),-1,1.8,180,"Walk through centre")
	_check(body.position.z < -2.4,"1.95m capsule crosses opening at walking speed")
	await _walk(body,Vector3(0,.01,-2.6),1,4.5,75,"Run back through centre")
	_check(body.position.z > 2.6,"1.95m capsule crosses opening at running speed")
	for x: float in [-2.2,2.2]:
		await _walk(body,Vector3(x,.01,2),-1,4.5,60,"Post blocks at x="+str(x))
		_check(body.position.z > .40 and body.position.z < .49,"Post stops actual move_and_slide capsule")
	body.queue_free()
	await process_frame
	var copies: Array[Node3D] = [first]
	for index: int in range(7):
		var copy: Node3D = ASSET.instantiate()
		world.add_child(copy)
		copies.append(copy)
	for index: int in range(copies.size()):
		copies[index].position = Vector3((index%4)*6-9,0,(index/4)*8-4)
		var current: Dictionary = _meshes(copies[index])
		var shared: bool = true
		for name: String in meshes:
			shared = shared and current[name].mesh == meshes[name].mesh
		_check(shared,"All three meshes and their material resources are shared: copy "+str(index))
	if graphical:
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(.10,.14,.17)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(.85,.9,1)
		environment.environment.ambient_light_energy = .85
		world.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-25,0)
		sun.light_energy = 1.15
		sun.shadow_enabled = true
		world.add_child(sun)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 26
		world.add_child(camera)
		camera.position = Vector3(13,13,19)
		camera.look_at(Vector3(0,1,0))
		await _capture("eight_instances")
		for index: int in range(1,copies.size()): copies[index].hide()
		first.position = Vector3.ZERO
		camera.size = 5.5
		camera.position = Vector3(6,4.3,7.7)
		camera.look_at(Vector3(0,1.3,0))
		await _capture("three_quarter")
		var avatar: CartoonActor = load("res://scenes/characters/ren_pixal_visual.tscn").instantiate()
		avatar.position = Vector3(1.0,0,.55)
		world.add_child(avatar)
		camera.size = 3.2
		camera.position = Vector3(0,1.35,8)
		camera.look_at(Vector3(0,1.35,0))
		await _capture("front_scale")
		avatar.hide()
		camera.size = .9
		camera.position = Vector3(-1.2,2.15,1.4)
		camera.look_at(Vector3(-2.2,2.08,0))
		await _capture("strap_detail")
	var report: Dictionary = {"checks":checks,"failures":failures,"triangles":triangles,"budget":LIMIT,
		"instances":8,"triangle_instances":triangles*8,"materials":materials.keys(),"movement":movement,
		"graphical":graphical,"no_focus_window":root.unfocusable,"captures":captures,"physical_input":false,"formal_map_integrated":false,
		"method":"Standalone actual imported mesh bounds, shared resource checks and CharacterBody3D capsule motion; not the full Player/InputMap, a formal map route or a performance benchmark."}
	FileAccess.open(OUT+("/graphical.json" if graphical else "/structural.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MINE_SUPPORT_RESULT checks=%d failures=%d graphical=%s" % [checks,failures.size(),str(graphical)])
	world.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
