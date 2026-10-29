extends SceneTree
var checks: int=0
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var player_shape: Shape3D
var player_transform: Transform3D

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, title: String) -> void:
	checks+=1
	if not ok:
		failures.append(title)
		if failures.size()<15: print("FAIL ",title)

func _world() -> SubViewport:
	var viewport:=SubViewport.new()
	viewport.world_3d=World3D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	return viewport

func _run() -> void:
	var player: Node3D=load("res://scenes/characters/player.tscn").instantiate()
	var collider:=player.get_node("CollisionShape3D") as CollisionShape3D
	player_shape=collider.shape
	player_transform=collider.transform
	player.free()
	for path: String in ["res://scenes/world/reference_candidate/greystone_runtime.tscn","res://scenes/world/expanded/forest.tscn","res://scenes/world/mine_reference/mine.tscn"]:
		await _map(path)
	await _synthetic_contract()
	DirAccess.make_dir_recursive_absolute("user://collision_snapshot")
	FileAccess.open("user://collision_snapshot/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":cases,"engine":Engine.get_version_info().string,"scope":"Independent real full-map versus physics-snapshot queries, including Lia before/after recruitment; not visual or input acceptance."},"  "))
	print("COLLISION_SNAPSHOT_RESULT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _map(path: String) -> void:
	var original:=_world()
	var map: Node3D=load(path).instantiate()
	original.add_child(map)
	await physics_frame
	var snapshot:=LocationCollisionSnapshot.capture(map)
	_check(snapshot!=null,"Capture supported map "+path)
	if snapshot==null: original.free();return
	var base_checks: int=checks
	for recruited: bool in [false,true]:
		for target: Node in map.find_children("*","WorldInteractable",true,false):
			if (target as WorldInteractable).interaction_id==&"npc_lia":
				(target as WorldInteractable).set_present(not recruited)
		var copied:=_world()
		var proxy: Node3D=snapshot.instantiate({"e003_done":recruited})
		copied.add_child(proxy)
		_check(proxy.find_children("*","VisualInstance3D",true,false).is_empty(),"Validation snapshot has no render objects")
		await physics_frame
		await physics_frame
		var a: PhysicsDirectSpaceState3D=original.world_3d.direct_space_state
		var b: PhysicsDirectSpaceState3D=copied.world_3d.direct_space_state
		for x: int in range(-56,57,4):
			for z: int in range(-56,57,4):
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,32,z),Vector3(x,-12,z),1)
				var first: Dictionary=a.intersect_ray(ray)
				var second: Dictionary=b.intersect_ray(ray)
				_check(first.is_empty()==second.is_empty(),"Ground availability "+str(Vector2(x,z)))
				if not first.is_empty() and not second.is_empty():
					_check((first.position as Vector3).distance_to(second.position)<.001,"Ground height matches")
					_compare(a,b,first.position+Vector3.UP*.02)
				_compare(a,b,Vector3(x,.1,z))
		for target: Node in map.find_children("*","WorldInteractable",true,false):
			_compare(a,b,(target as Node3D).global_position)
		copied.free()
	cases.append({"map":path,"body_count":snapshot.bodies.size(),"checks":checks-base_checks})
	original.free()
	await physics_frame

func _compare(a: PhysicsDirectSpaceState3D,b: PhysicsDirectSpaceState3D,position: Vector3) -> void:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=player_shape
	query.transform=Transform3D(Basis.IDENTITY,position+Vector3.UP*.06)*player_transform
	query.collision_mask=1
	_check(a.intersect_shape(query,1).is_empty()==b.intersect_shape(query,1).is_empty(),"Player capsule collision matches "+str(position))
	var ray:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.15,position+Vector3.DOWN*.35,1)
	_check(a.intersect_ray(ray).is_empty()==b.intersect_ray(ray).is_empty(),"Standing support matches")

func _synthetic_contract() -> void:
	var viewport:=_world()
	var map:=Node3D.new()
	viewport.add_child(map)
	var body:=StaticBody3D.new()
	map.add_child(body)
	var shape:=BoxShape3D.new();shape.size=Vector3(2,3,4)
	var owner_id: int=body.create_shape_owner(body)
	body.shape_owner_add_shape(owner_id,shape)
	body.shape_owner_set_transform(owner_id,Transform3D(Basis.IDENTITY,Vector3(1,2,3)))
	body.shape_owner_set_disabled(owner_id,true)
	var snapshot:=LocationCollisionSnapshot.capture(map)
	shape.size=Vector3(20,30,40)
	_check(snapshot.bodies[0].owners[0].shapes[0].size==Vector3(2,3,4),"Snapshot independent of later live shape mutation")
	_check(snapshot.bodies[0].owners[0].disabled,"Disabled shape-owner flag retained")
	_check(snapshot.bodies[0].owners[0].transform.origin==Vector3(1,2,3),"Local shape-owner transform retained")
	var dynamic_body:=RigidBody3D.new();map.add_child(dynamic_body)
	_check(LocationCollisionSnapshot.capture(map)==null,"Unsupported dynamic bodies preserve original-scene fallback")
	dynamic_body.free()
	viewport.free()
	await physics_frame
