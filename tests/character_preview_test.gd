extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,800)
	var viewer: Node3D = load("res://scenes/tools/character_preview.tscn").instantiate()
	root.add_child(viewer)
	await create_timer(.3).timeout
	var info: Label = viewer.get("info")
	_check(info.text.contains("19 骨") and info.text.contains("4582"),"Lia resources and exact mesh budget load")
	var staff: CheckBox = viewer.get("staff_toggle")
	await _click(staff)
	_check(staff.button_pressed and info.text.contains("4722"),"Mouse toggles staff and exact combined budget")
	var actions: Dictionary = viewer.get("action_buttons")
	await _click(actions[&"mend"])
	var actor: CartoonActor = viewer.get("actor")
	_check(actor.get("battle_pose")==&"mend","Mouse starts imported cast")
	await create_timer(.8).timeout
	var closeup: CheckBox = viewer.get("closeup_toggle")
	await _click(closeup)
	_check(closeup.button_pressed and is_equal_approx((viewer.get("camera") as Camera3D).size,.58),"Mouse opens face view")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/viewer_face.webp")
	await _click(closeup)
	var angles: HSlider = viewer.get("angle_slider")
	angles.value = 70
	_check(is_equal_approx(actor.rotation.y,deg_to_rad(70)),"Angle control rotates actor")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/viewer_lia.webp")
	var choices: Array = viewer.get("character_buttons")
	await _click(choices[0])
	await create_timer(.1).timeout
	actor = viewer.get("actor")
	_check(choices[0].button_pressed and actor.model.resource_path.ends_with("ren_user.glb"),"Mouse selects Ren")
	_check(staff.disabled and actions[&"mend"].disabled,"Unavailable Ren controls disabled")
	_check(info.text.contains("4579"),"Ren exact mesh budget loads")
	var motions: Array = viewer.get("motion_buttons")
	await _click(motions[2])
	await create_timer(.2).timeout
	_check(is_equal_approx(actor.get("_motion"),1.0),"Mouse selects running intensity")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/viewer_ren.webp")
	_check(viewer.find_child("Saves",true,false)==null and viewer.find_child("Party",true,false)==null,"Viewer has no game save or party services")
	var before_files: int = DirAccess.get_files_at("user://character_previews").size() if DirAccess.dir_exists_absolute("user://character_previews") else 0
	for button: Node in viewer.find_children("*","Button",true,false):
		if (button as Button).text == "保存預覽圖": await _click(button)
	await create_timer(.1).timeout
	_check(DirAccess.get_files_at("user://character_previews").size()==before_files+1,"Mouse saves a new preview image")
	_check((viewer.get("status") as Label).text=="已保存預覽圖。","Save result shown to user")
	print("CHARACTER_PREVIEW_RESULT checks=%d failures=%d" % [checks,failures])
	viewer.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _click(control: Control) -> void:
	var point: Vector2 = root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size*.5)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = point
	Input.parse_input_event(move)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await create_timer(.05).timeout

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
