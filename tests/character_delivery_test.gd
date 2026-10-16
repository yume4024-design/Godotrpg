class_name CharacterDeliveryTestTree
extends "res://tests/greystone_story_test.gd"
## Release-template verification, isolated from formal builds and save slots.

func _run() -> void:
	slot = "user://character_qa/prologue.json"
	visual_slot = slot
	DirAccess.make_dir_recursive_absolute("user://character_qa/evidence")
	_check(OS.has_feature("character_qa") and not OS.is_debug_build(),"Independent character QA release template")
	if "--reload" not in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,800)
		var viewer: Node3D = load("res://scenes/tools/character_preview.tscn").instantiate()
		root.add_child(viewer)
		await create_timer(.3).timeout
		var actor: CartoonActor = viewer.get("actor")
		var rig: Skeleton3D = actor.get("skeleton")
		_check(rig.get_bone_count()==29,"Export contains complete Lia skeleton")
		var player: AnimationPlayer = actor.get("animation_player")
		for clip: StringName in [&"attack",&"cast",&"guard",&"hit",&"potion",&"walk",&"run"]:
			_check(player.has_animation(clip),"Exported animation: "+clip)
		_check(actor.get("motion_profile") is CharacterMotionProfile,"Export contains motion Resource and script")
		await _click_control(viewer.get("staff_toggle"))
		_check((actor.get("staff_visual") as Node3D).visible,"Exported UI equips visual staff")
		await _click_control(viewer.get("action_buttons")[&"mend"])
		_check(actor.get("battle_pose")==&"mend","Exported UI plays cast")
		await create_timer(.3).timeout
		await _capture("character-cast")
		await create_timer(.5).timeout
		_check(actor.get("battle_pose")==&"","Exported animation finishes")
		var eyes: Array[MeshInstance3D] = actor.get("_blink_meshes")
		_check(eyes.size()==8,"Export includes eight facial morph surfaces")
		viewer.queue_free()
		await process_frame
	await super._run()

func _click_control(control: Control) -> void:
	var center: Vector2 = root.get_final_transform() * control.get_global_transform_with_canvas() * (control.size*.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = center
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":
		_check(false,"Release QA requires graphics")
		return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp("user://character_qa/evidence/"+name+".webp")==OK,"Release evidence: "+name)
