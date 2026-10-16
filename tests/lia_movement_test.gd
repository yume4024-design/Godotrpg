extends SceneTree
var checks: int = 0
var failures: int = 0
var player: ExplorationPlayer

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var preview: Node3D = load("res://scenes/tools/lia_movement_preview.tscn").instantiate()
	root.add_child(preview)
	player = preview.get("player")
	await create_timer(.3).timeout
	_check(player.is_on_floor(),"Shared controller grounds Lia at village entrance")
	_check(player.appearance.model.resource_path.ends_with("lia_rigged.glb"),"Player uses production Lia visual")
	var placement: LiaFootPlacement = preview.get("foot_placement")
	_check(not placement.enabled,"Experimental foot placement defaults off")
	var toggle: CheckBox = preview.find_child("FootPlacementToggle",true,false)
	var center: Vector2 = root.get_final_transform()*toggle.get_global_transform_with_canvas()*(toggle.size*.5)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	_check(toggle.button_pressed and placement.enabled,"Mouse enables optional foot placement")
	var begin: Vector3 = player.position
	_press(Vector2(.5,0))
	for frame: int in range(35):
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await physics_frame
	var speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	_check(player.position.distance_to(begin)>.4,"Analog InputMap moves actual capsule")
	_check(speed>0 and speed<player.movement.speed,"Analog motion retains partial speed")
	_check((player.appearance.get("animation_player") as AnimationPlayer).current_animation==&"walk","Partial movement selects walk")
	_check(player.appearance.get("last_motion_rate")>.5,"Physical speed drives playback rate")
	print("LIA_ANALOG_SPEED meters_per_second=%.3f animation_rate=%.3f" % [speed,player.appearance.get("last_motion_rate")])
	_release()
	await create_timer(.25).timeout
	_check(Vector2(player.velocity.x,player.velocity.z).length()<.01,"Release stops capsule")
	_check(not (player.appearance.get("animation_player") as AnimationPlayer).is_playing(),"Release blends back to idle")
	_check(placement.last_target_errors.size()==2,"Preview feet sample real village collision")
	player.reset_to(Vector3(0,0,18))
	for point: Vector3 in [Vector3(6,0,6),Vector3(6,0,-6),Vector3(0,0,-18)]:
		await _walk(point,350)
		_check(Vector2(player.position.x-point.x,player.position.z-point.z).length()<.4,"Shared controller reaches route point "+str(point))
		_check(player.is_on_floor(),"Lia remains grounded on route")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/female_character/movement_%d.webp" % checks)
	player.reset_to(Vector3(0,0,-23))
	await create_timer(.15).timeout
	await _walk(Vector3(0,0,-31),100)
	_check(player.position.z>-25.0 and player.position.z<-23.2,"Existing guild collision stops capsule")
	await create_timer(.25).timeout
	_check(not (player.appearance.get("animation_player") as AnimationPlayer).is_playing(),"Blocked movement ends gait")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/movement_wall.webp")
	_check(preview.find_child("Saves",true,false)==null,"Preview does not instantiate save service")
	_release()
	print("LIA_MOVEMENT_RESULT checks=%d failures=%d" % [checks,failures])
	preview.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _walk(target: Vector3,frames: int) -> void:
	for frame: int in range(frames):
		player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var delta: Vector2 = Vector2(target.x-player.position.x,target.z-player.position.z)
		if delta.length()<.22: break
		var direction: Vector2 = delta.normalized()
		_press(Vector2(direction.x-direction.y,direction.x+direction.y)*.70710678)
		await physics_frame
	_release()
	await physics_frame

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
