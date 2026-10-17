extends SceneTree
const SURFACE_PROBE = preload("res://tests/female_slope_test.gd")
var checks: int = 0
var failures: int = 0
var player: ExplorationPlayer
var _missed_rays: int = 0
var _samples: int = 0
var _grounded: int = 0
var _minimum: float = INF
var _highest_stance: float = -INF
var _finite_pose: bool = true
var _stops: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var site: String = "inn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--site="): site = argument.trim_prefix("--site=")
	var routes: Dictionary = {
		"inn":[Vector2(-10,10),Vector2(-10,-10),Vector2(-20,-11),Vector2(-10,-10),Vector2(-10,10),Vector2(0,18)],
		"farm":[Vector2(-10,10),Vector2(-12,-10),Vector2(-12,-27),Vector2(-28,-27),Vector2(-42,-29),Vector2(-28,-27),Vector2(-12,-27),Vector2(-12,-10),Vector2(-10,10),Vector2(0,18)],
		"mine":[Vector2(8,16),Vector2(8,-18),Vector2(0,-18),Vector2(0,-22),Vector2(12,-22),Vector2(12,-28),Vector2(24,-28),Vector2(24,-44),Vector2(24,-52),Vector2(24,-44),Vector2(24,-28),Vector2(12,-28),Vector2(12,-22),Vector2(0,-22),Vector2(0,-18),Vector2(8,-18),Vector2(8,16),Vector2(0,18)]}
	if not routes.has(site):
		push_error("Unknown village route")
		quit(1)
		return
	var preview: Node3D = load("res://scenes/tools/lia_movement_preview.tscn").instantiate()
	root.add_child(preview)
	player = preview.get("player")
	var placement: LiaFootPlacement = preview.get("foot_placement")
	placement.enabled = true
	(preview.find_child("FootPlacementToggle",true,false) as CheckBox).set_pressed_no_signal(true)
	var rig: Skeleton3D = player.appearance.get("skeleton")
	var body: MeshInstance3D = player.appearance.find_child("LiaBody",true,false)
	await create_timer(.5).timeout
	for point: Vector2 in routes[site]:
		var reached: bool = await _walk(point,body,rig)
		_check(reached,"Real village route reaches "+str(point))
		if not reached: break
		if player.position.y>.5:
			for frame: int in range(18):
				await physics_frame
				await RenderingServer.frame_post_draw
				_observe(body,rig)
			_check(Vector2(player.velocity.x,player.velocity.z).length()<.01,"Controller stops at elevated waypoint "+str(point))
			_stops += 1
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_webp("res://artifacts/female_character/village_route_%s_%d_%d.webp" % [site,int(point.x),int(point.y)])
	_release()
	await create_timer(.3).timeout
	_check(_samples>120,"Route contains sustained physical movement")
	_check(_grounded>=_samples*.95,"Capsule stays grounded on actual village terrain")
	_check(_missed_rays==0,"All sampled foot vertices have physical support below")
	_check(is_finite(_minimum) and _minimum>-.025,"Imported feet avoid deep physical-terrain penetration")
	_check(is_finite(_highest_stance) and _highest_stance<.045,"At least one foot remains near physical terrain")
	_check(_finite_pose,"Turning and stopping leave finite bone transforms")
	_check(_stops>0,"Route includes measured elevated stops")
	_check(preview.find_child("Saves",true,false)==null,"Route does not create or write game saves")
	print("VILLAGE_ROUTE site=",site," samples=",_samples," grounded=",_grounded," missed_rays=",_missed_rays," minimum_physical_sole_m=",_minimum," highest_physical_stance_m=",_highest_stance)
	print("ROUTE_STOPS count=",_stops)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/village_route_%s.webp" % site)
	preview.queue_free()
	await process_frame
	print("LIA_VILLAGE_ROUTE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _walk(target: Vector2,body: MeshInstance3D,rig: Skeleton3D) -> bool:
	var best: float = INF
	var stalled: int = 0
	for frame: int in range(720):
		var difference: Vector2 = target-Vector2(player.position.x,player.position.z)
		if difference.length()<.22:
			_release()
			return true
		if difference.length()<best-.03:
			best = difference.length()
			stalled = 0
		else: stalled += 1
		if stalled>90: break
		var direction: Vector2 = difference.normalized()
		var input: Vector2 = Vector2(direction.x-direction.y,direction.x+direction.y)*.70710678
		_release()
		Input.action_press(&"move_right" if input.x>0 else &"move_left",absf(input.x))
		Input.action_press(&"move_back" if input.y>0 else &"move_forward",absf(input.y))
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await physics_frame
		await RenderingServer.frame_post_draw
		_observe(body,rig)
	_release()
	print("STALLED_ROUTE target=",target," player=",player.position)
	return false

func _observe(body: MeshInstance3D,rig: Skeleton3D) -> void:
	var soles: Dictionary[String,float] = SURFACE_PROBE._soles(body,rig,Vector3.UP,_physical_distance)
	_minimum = minf(_minimum,minf(soles.Left,soles.Right))
	_highest_stance = maxf(_highest_stance,minf(soles.Left,soles.Right))
	for bone: int in range(rig.get_bone_count()):
		if not rig.get_bone_global_pose(bone).is_finite(): _finite_pose = false
	_samples += 1
	if player.is_on_floor(): _grounded += 1

func _physical_distance(point: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point+Vector3.UP*.35,point-Vector3.UP*.65,player.collision_mask)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_missed_rays += 1
		return INF
	var normal: Vector3 = hit.normal
	if normal.y<0: normal = -normal
	return normal.dot(point-(hit.position as Vector3))

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"move_forward",&"move_back"]: Input.action_release(action)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
